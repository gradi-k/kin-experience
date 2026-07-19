/**
 * Import des données Google Maps → Firebase Firestore
 * Projet City Guide (Kinshasa)
 *
 * 108 lieux : 20 enrichis (GPS+photo+horaires) + 88 basiques (géocodage auto)
 *
 * Prérequis :
 * npm install firebase-admin node-fetch@2
 *
 * Usage :
 * 1. Place serviceAccountKey.json dans ce dossier
 * (Console Firebase → Paramètres → Comptes de service → Générer clé)
 * 2. node import_to_firestore.js
 */

const admin = require('firebase-admin');
const fetch = require('node-fetch');
const fs = require('fs');
const path = require('path');

// ═══════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════

const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'serviceAccountKey.json');

// Remplacement de DATA_PATH par un tableau de fichiers
const DATA_FILES = [
  'firestore_ready.json',
  'firestore_ready_batch1a.json',
  'firestore_ready_batch1b.json',
  'firestore_ready_batch2.json',
  'firestore_ready_batch3.json',
  'firestore_ready_lingwala.json'
];

const NOMINATIM_DELAY_MS = 1100;
const KINSHASA_CENTER = { lat: -4.3250, lng: 15.3222 };

// ═══════════════════════════════════════════════════════════════
// INIT FIREBASE
// ═══════════════════════════════════════════════════════════════

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('❌ serviceAccountKey.json introuvable !');
  console.error('   Console Firebase → Paramètres → Comptes de service → Générer une clé');
  process.exit(1);
}

const serviceAccount = require(SERVICE_ACCOUNT_PATH);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════
// GÉOCODAGE NOMINATIM (pour les lieux sans GPS)
// ═══════════════════════════════════════════════════════════════

const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function geocode(name, address) {
  const queries = [
    `${name}, Kinshasa, DR Congo`,
    `${address}`,
    `${name}, Kinshasa`,
  ];

  for (const query of queries) {
    if (!query || query.trim().length < 3) continue;
    try {
      const url = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(query)}&format=json&limit=1&countrycodes=cd`;
      const res = await fetch(url, { headers: { 'User-Agent': 'CityGuideImport/1.0' } });
      const data = await res.json();
      if (data && data.length > 0) {
        return { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon), success: true };
      }
      await sleep(NOMINATIM_DELAY_MS);
    } catch (_) {}
  }

  // Fallback : centre Kinshasa + décalage aléatoire
  return {
    lat: KINSHASA_CENTER.lat + (Math.random() - 0.5) * 0.03,
    lng: KINSHASA_CENTER.lng + (Math.random() - 0.5) * 0.03,
    success: false,
  };
}

// ═══════════════════════════════════════════════════════════════
// IMPORT
// ═══════════════════════════════════════════════════════════════

async function importData() {
  console.log('📖 Lecture des données...');

  let data = [];

  // Lecture de tous les fichiers et fusion dans le tableau "data"
  for (const filename of DATA_FILES) {
    const filePath = path.join(__dirname, filename);
    if (fs.existsSync(filePath)) {
      const fileData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      data = data.concat(fileData);
      console.log(`   📄 Chargé : ${filename} (${fileData.length} lieux)`);
    } else {
      console.warn(`   ⚠️ Fichier introuvable : ${filename}`);
    }
  }

  console.log(`\n   => Total : ${data.length} lieux à importer\n`);

  let imported = 0, skipped = 0, geocoded = 0, fallback = 0;
  const stats = {};

  for (let i = 0; i < data.length; i++) {
    const place = data[i];
    const collection = place.collection;
    stats[collection] = (stats[collection] || 0) + 1;

    // ── Vérifier doublon ──
    if (place.googlePlaceId) {
      const existing = await db.collection(collection)
        .where('googlePlaceId', '==', place.googlePlaceId)
        .limit(1).get();
      if (!existing.empty) {
        console.log(`   ⏭  [${i+1}/${data.length}] ${place.nom} (déjà importé)`);
        skipped++;
        continue;
      }
    }

    // ── Géocodage si nécessaire ──
    const needsGeocode = !place.latitude || !place.longitude ||
      (Math.abs(place.latitude - KINSHASA_CENTER.lat) < 0.001 && Math.abs(place.longitude - KINSHASA_CENTER.lng) < 0.001);

    if (needsGeocode) {
      process.stdout.write(`   🌍 [${i+1}/${data.length}] Géocodage "${place.nom}"...`);
      const coords = await geocode(place.nom, place.address);
      place.latitude = coords.lat;
      place.longitude = coords.lng;
      if (coords.success) {
        geocoded++;
        console.log(` ✅ (${coords.lat.toFixed(4)}, ${coords.lng.toFixed(4)})`);
      } else {
        fallback++;
        console.log(` ⚠️ fallback`);
      }
      await sleep(NOMINATIM_DELAY_MS);
    }

    // ── Préparer le document (retirer le champ "collection") ──
    const doc = { ...place };
    delete doc.collection;
    doc.importedAt = admin.firestore.FieldValue.serverTimestamp();

    // ── Écriture Firestore ──
    await db.collection(collection).add(doc);
    imported++;
    const enrichLabel = place.photos && place.photos.length > 0 ? '📸' : '  ';
    console.log(`   ✅ ${enrichLabel} [${i+1}/${data.length}] [${collection}] ${place.nom}`);
  }

  // ── Résumé ──
  console.log('\n' + '═'.repeat(55));
  console.log('🎉 IMPORT TERMINÉ');
  console.log('═'.repeat(55));
  console.log(`   ✅ Importés    : ${imported}`);
  console.log(`   ⏭  Doublons    : ${skipped}`);
  console.log(`   🌍 Géocodés    : ${geocoded}`);
  console.log(`   ⚠️  Fallback    : ${fallback}`);
  console.log(`\n   Par collection :`);
  for (const [col, count] of Object.entries(stats).sort((a,b) => b[1]-a[1])) {
    console.log(`     📁 ${col}: ${count}`);
  }
  console.log('═'.repeat(55));
}

importData()
  .then(() => { console.log('\n✅ Terminé.'); process.exit(0); })
  .catch(err => { console.error('\n❌ Erreur:', err); process.exit(1); });
