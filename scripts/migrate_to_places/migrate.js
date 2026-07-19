/**
 * migrate.js
 * Migration vers les catégories dynamiques.
 *
 * Fait deux choses :
 *   1. Crée la collection `categories` avec les 6 catégories historiques.
 *   2. Copie sites/restaurants/hotels/events/business/shopping → `places`,
 *      en ajoutant `categoryKey` et en normalisant la forme des documents.
 *
 * NON DESTRUCTIF : les 6 collections d'origine ne sont PAS supprimées. Le
 * retour arrière consiste à supprimer `places` et `categories`.
 *
 * IDEMPOTENT : les ids de documents sont conservés, donc rejouer le script
 * réécrit les mêmes documents au lieu d'en créer des doublons. Les ids étant
 * préservés, les liens de partage et les notifications déjà envoyées
 * continuent de fonctionner.
 *
 * Prérequis :
 *   npm install                      (dans ce dossier)
 *   serviceAccountKey.json           (Console Firebase → Paramètres →
 *                                     Comptes de service → Générer une clé)
 *
 * Usage :
 *   node migrate.js --dry-run        → affiche ce qui serait fait, n'écrit rien
 *   node migrate.js                  → exécute la migration
 *   node migrate.js --categories-only → ne crée que les catégories
 *   node migrate.js --favorites      → remet aussi à niveau les favoris
 *
 * Ordre conseillé :
 *   1. node migrate.js --dry-run           (vérifier les totaux)
 *   2. node migrate.js                     (migrer)
 *   3. firebase deploy --only firestore:indexes
 *   4. Vérifier l'app
 *   5. firebase deploy --only firestore:rules
 */

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, 'serviceAccountKey.json'));

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

const DRY_RUN = process.argv.includes('--dry-run');
const CATEGORIES_ONLY = process.argv.includes('--categories-only');
const WITH_FAVORITES = process.argv.includes('--favorites');

// Limite d'un batch Firestore.
const BATCH_SIZE = 500;

// ─────────────────────────────────────────────────────────────────────────
// Les 6 catégories historiques.
//
// `collection` = collection source ; `key` = futur categoryKey. Les libellés
// et icônes reprennent ceux qui étaient codés en dur dans l'app.
// ─────────────────────────────────────────────────────────────────────────
const LEGACY_CATEGORIES = [
  {
    collection: 'sites',
    key: 'site',
    label: { fr: 'Sites', en: 'Sites' },
    icon: 'place',
    order: 0,
    ctaLabel: { fr: 'Visiter', en: 'Visit' },
    ctaIcon: 'attractions',
  },
  {
    collection: 'hotels',
    key: 'hotel',
    label: { fr: 'Hôtels', en: 'Hotels' },
    icon: 'hotel',
    order: 1,
    ctaLabel: { fr: 'Réserver', en: 'Book' },
    ctaIcon: 'hotel',
  },
  {
    collection: 'restaurants',
    key: 'resto',
    label: { fr: 'Restaurants', en: 'Restaurants' },
    icon: 'restaurant',
    order: 2,
    ctaLabel: { fr: 'Réserver ou commander', en: 'Book or order' },
    ctaIcon: 'restaurant',
  },
  {
    collection: 'events',
    key: 'event',
    label: { fr: 'Événements', en: 'Events' },
    icon: 'event',
    order: 3,
    ctaLabel: { fr: 'Acheter un billet', en: 'Buy a ticket' },
    ctaIcon: 'celebration',
  },
  {
    // ⚠️ Le code client lisait `business` tandis que places_service.dart et
    // les Cloud Functions parlaient d'`entreprises`. `business` est la
    // collection qui contient réellement les données — voir le contrôle
    // ci-dessous, qui alerte si `entreprises` n'est pas vide.
    collection: 'business',
    key: 'entreprise',
    label: { fr: 'Business', en: 'Business' },
    icon: 'business',
    order: 4,
    ctaLabel: { fr: 'Contacter l’entreprise', en: 'Contact' },
    ctaIcon: 'business_center',
  },
  {
    collection: 'shopping',
    key: 'shopping',
    label: { fr: 'Market', en: 'Market' },
    icon: 'shopping_bag',
    order: 5,
    ctaLabel: { fr: 'Découvrir la boutique', en: 'Visit the shop' },
    ctaIcon: 'storefront',
  },
];

function log(...args) {
  console.log(...args);
}

// ─────────────────────────────────────────────────────────────────────────
// Normalisation d'un document de lieu
// ─────────────────────────────────────────────────────────────────────────

function toNumber(v, fallback = 0) {
  if (typeof v === 'number' && !Number.isNaN(v)) return v;
  if (typeof v === 'string') {
    const n = parseFloat(v);
    if (!Number.isNaN(n)) return n;
  }
  return fallback;
}

function toStringList(v) {
  if (Array.isArray(v)) return v.map(String);
  if (typeof v === 'string' && v.trim() !== '') {
    return v.includes(',') ? v.split(',').map((s) => s.trim()).filter(Boolean) : [v];
  }
  return [];
}

function orNull(v) {
  if (v === undefined || v === null) return null;
  const s = String(v).trim();
  return s === '' ? null : s;
}

/**
 * Transforme un document hérité en document `places`.
 *
 * Tolère les deux formes présentes en base :
 *   - plat : latitude/longitude + champs à la racine (add_content_form)
 *   - GeoPoint : `location` + champs métier sous `meta` (brouillons publiés
 *     par l'ancien ContentService — ces documents étaient d'ailleurs cassés
 *     dans l'app, qui lisait `latitude` et ne trouvait rien)
 */
function normalizePlace(data, categoryKey) {
  const meta = data.meta && typeof data.meta === 'object' ? data.meta : {};
  const pick = (key) => (data[key] !== undefined ? data[key] : meta[key]);

  let lat = toNumber(data.latitude);
  let lng = toNumber(data.longitude);

  if (lat === 0 && lng === 0 && data.location) {
    const loc = data.location;
    if (typeof loc.latitude === 'number' && typeof loc.longitude === 'number') {
      lat = loc.latitude;
      lng = loc.longitude;
    } else if (typeof loc === 'object') {
      lat = toNumber(loc.latitude);
      lng = toNumber(loc.longitude);
    }
  }

  // `communities` était écrit uniquement pour la catégorie « entreprise » et
  // n'était lu nulle part ; on le préserve dans extras plutôt que le perdre.
  const extras = {};
  const communities = toStringList(pick('communities'));
  if (communities.length > 0) extras.communities = communities;

  return {
    categoryKey,
    nom: String(pick('nom') || ''),
    description: String(pick('description') || ''),
    rating: toNumber(pick('rating')),
    latitude: lat,
    longitude: lng,
    location: new admin.firestore.GeoPoint(lat, lng),
    photos: toStringList(data.photos !== undefined ? data.photos : meta.photos),
    prixRange: String(pick('prixRange') || ''),
    isFeatured: pick('isFeatured') === true,
    // Explicitement false et non absent : les requêtes publiques filtrent
    // `isDraft == false`, et une requête d'égalité ignore les documents où le
    // champ n'existe pas.
    isDraft: pick('isDraft') === true,
    address: orNull(pick('address')),
    phone: orNull(pick('phone')),
    email: orNull(pick('email')),
    website: orNull(pick('website')),
    facebookUrl: orNull(pick('facebookUrl')),
    instagramUrl: orNull(pick('instagramUrl')),
    tiktokUrl: orNull(pick('tiktokUrl')),
    amenities: toStringList(pick('amenities')),
    schedule: orNull(pick('schedule')),
    reviewCount: Math.trunc(toNumber(pick('reviewCount'))),
    distanceKm: toNumber(pick('distanceKm')),
    menuUrl: orNull(pick('menuUrl')),
    menuType: orNull(pick('menuType')),
    extras,
    createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
    // updatedAt porte le tri de toutes les listes : il doit toujours exister.
    updatedAt: data.updatedAt || admin.firestore.FieldValue.serverTimestamp(),
    migratedFrom: LEGACY_CATEGORIES.find((c) => c.key === categoryKey).collection,
    migratedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

// ─────────────────────────────────────────────────────────────────────────
// Étapes
// ─────────────────────────────────────────────────────────────────────────

async function migrateCategories() {
  log('\n📁 Catégories');

  for (const cat of LEGACY_CATEGORIES) {
    const doc = {
      label: cat.label,
      icon: cat.icon,
      order: cat.order,
      enabled: true,
      fields: [],
      ctaLabel: cat.ctaLabel,
      ctaIcon: cat.ctaIcon,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (DRY_RUN) {
      log(`   [dry-run] categories/${cat.key} ← ${cat.label.fr}`);
    } else {
      // merge : rejouer le script ne réinitialise pas les champs ajoutés
      // depuis l'admin (champs personnalisés, ordre, couleur).
      await db.collection('categories').doc(cat.key).set(doc, { merge: true });
      log(`   ✅ categories/${cat.key}`);
    }
  }
}

async function migrateCollection(cat) {
  const snap = await db.collection(cat.collection).get();

  if (snap.empty) {
    log(`   ⏭️  ${cat.collection} : vide`);
    return { migrated: 0, drafts: 0 };
  }

  let migrated = 0;
  let drafts = 0;
  let batch = db.batch();
  let inBatch = 0;

  for (const doc of snap.docs) {
    const place = normalizePlace(doc.data(), cat.key);
    if (place.isDraft) drafts += 1;

    if (!DRY_RUN) {
      // Même id que la source : rejouable, et les liens partagés restent
      // valides.
      batch.set(db.collection('places').doc(doc.id), place, { merge: true });
      inBatch += 1;

      if (inBatch >= BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        inBatch = 0;
      }
    }

    migrated += 1;
  }

  if (!DRY_RUN && inBatch > 0) await batch.commit();

  const suffix = drafts > 0 ? ` (dont ${drafts} brouillon(s))` : '';
  log(`   ${DRY_RUN ? '[dry-run]' : '✅'} ${cat.collection} → places : ${migrated}${suffix}`);

  return { migrated, drafts };
}

async function migratePlaces() {
  log('\n📍 Lieux');

  let total = 0;
  let totalDrafts = 0;

  for (const cat of LEGACY_CATEGORIES) {
    const { migrated, drafts } = await migrateCollection(cat);
    total += migrated;
    totalDrafts += drafts;
  }

  log(`\n   Total : ${total} lieu(x), dont ${totalDrafts} brouillon(s)`);
  return total;
}

/**
 * Remet les favoris à niveau.
 *
 * Ancien schéma : users/{uid}/favorites/{collectionName}_{placeId}, avec un
 * champ `category` contenant le nom de la collection.
 * Nouveau schéma : users/{uid}/favorites/{placeId}, avec `categoryKey`.
 *
 * Sans cette étape, les favoris existants ne correspondraient plus aux lieux
 * (l'id ne colle plus) et disparaîtraient de l'app.
 */
async function migrateFavorites() {
  log('\n⭐ Favoris');

  const byCollection = {};
  for (const c of LEGACY_CATEGORIES) byCollection[c.collection] = c.key;

  const users = await db.collection('users').get();
  let converted = 0;
  let skipped = 0;

  for (const user of users.docs) {
    const favs = await user.ref.collection('favorites').get();

    for (const fav of favs.docs) {
      const data = fav.data();
      const oldId = fav.id;

      // Id de la forme "<collection>_<placeId>".
      const underscore = oldId.indexOf('_');
      if (underscore === -1) {
        skipped += 1;
        continue;
      }

      const prefix = oldId.slice(0, underscore);
      const placeId = oldId.slice(underscore + 1);
      const categoryKey = byCollection[prefix] || byCollection[String(data.category || '')];

      if (!categoryKey || !placeId) {
        skipped += 1;
        continue;
      }

      if (DRY_RUN) {
        converted += 1;
        continue;
      }

      const place = normalizePlace(data, categoryKey);
      await user.ref.collection('favorites').doc(placeId).set(place, { merge: true });
      await fav.ref.delete();
      converted += 1;
    }
  }

  log(`   ${DRY_RUN ? '[dry-run]' : '✅'} ${converted} favori(s) converti(s), ${skipped} ignoré(s)`);
}

/**
 * Alerte si la collection `entreprises` contient des données.
 *
 * Les Cloud Functions écoutaient `entreprises` et `shoppings` alors que le
 * client lisait `business` et `shopping` : des documents ont pu atterrir dans
 * les mauvaises collections.
 */
async function checkOrphanCollections() {
  const suspects = ['entreprises', 'shoppings', 'restos'];

  for (const name of suspects) {
    const snap = await db.collection(name).limit(1).get();
    if (!snap.empty) {
      const all = await db.collection(name).get();
      log(
        `\n⚠️  La collection « ${name} » contient ${all.size} document(s) et n'est PAS migrée.`
      );
      log(`   Le client n'a jamais lu cette collection (incohérence héritée).`);
      log(`   Vérifiez son contenu avant de la supprimer ou de l'importer à la main.`);
    }
  }
}

async function main() {
  log('═'.repeat(64));
  log(DRY_RUN ? '🔍 SIMULATION — aucune écriture' : '🚀 MIGRATION');
  log(`   Projet : ${serviceAccount.project_id}`);
  log('═'.repeat(64));

  await migrateCategories();

  if (!CATEGORIES_ONLY) {
    await migratePlaces();
    if (WITH_FAVORITES) await migrateFavorites();
    await checkOrphanCollections();
  }

  log('\n' + '═'.repeat(64));
  if (DRY_RUN) {
    log('🔍 Simulation terminée. Relancez sans --dry-run pour appliquer.');
  } else {
    log('✅ Migration terminée.');
    log('   Les collections d\'origine sont intactes : supprimez-les');
    log('   seulement après avoir vérifié l\'application.');
    log('\n   Étape suivante : firebase deploy --only firestore:indexes');
  }
  log('═'.repeat(64));
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error('\n❌ Échec de la migration :', e);
    process.exit(1);
  });
