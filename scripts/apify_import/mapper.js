/**
 * mapper.js
 * Transforme un item brut de l'API Apify (Google Places Crawler)
 * vers le format Firestore de Kin Experience (Resto / Hotel).
 */

/**
 * Convertit le champ "price" Apify ("$", "$$", "$$$", "$$$$")
 * vers le prixRange de l'app.
 */
function mapPrixRange(price) {
  if (!price) return '';
  const map = {
    '$': 'Bon marché',
    '$$': 'Modéré',
    '$$$': 'Cher',
    '$$$$': 'Très cher',
  };
  return map[price] || price;
}

/**
 * Convertit les openingHours Apify vers une string lisible.
 * Apify retourne : [{ day: "Monday", hours: "9:00 AM – 10:00 PM" }, ...]
 */
function mapSchedule(openingHours) {
  if (!openingHours || !Array.isArray(openingHours) || openingHours.length === 0) {
    return null;
  }
  return openingHours
    .map((h) => `${h.day}: ${h.hours}`)
    .join(' | ');
}

/**
 * Extrait les URLs des photos depuis l'item Apify.
 * Apify retourne imageUrls[] ou images[].
 * On limite à 5 photos max pour ne pas surcharger Firestore.
 */
function mapPhotos(item) {
  const urls = item.imageUrls || item.images || [];
  return urls.slice(0, 5).filter((u) => typeof u === 'string' && u.startsWith('http'));
}

/**
 * Extrait les amenities depuis les champs disponibles Apify.
 * additionalInfo peut contenir des groupes (ex: "Accessibilité", "Options de service")
 */
function mapAmenities(additionalInfo) {
  if (!additionalInfo || typeof additionalInfo !== 'object') return [];

  const result = [];
  for (const [group, items] of Object.entries(additionalInfo)) {
    if (Array.isArray(items)) {
      items.forEach((item) => {
        if (typeof item === 'object') {
          // { "Service à table": true }
          for (const [key, val] of Object.entries(item)) {
            if (val === true) result.push(key);
          }
        } else if (typeof item === 'string') {
          result.push(item);
        }
      });
    }
  }
  return result;
}

/**
 * Transforme un item Apify en document Firestore compatible avec Resto / Hotel.
 *
 * @param {Object} item - Item brut depuis l'API Apify
 * @param {Object} options
 * @param {boolean} options.isFeatured - Marquer comme mis en avant (défaut: false)
 * @returns {Object} Document prêt pour Firestore
 */
function mapApifyItem(item, options = {}) {
  const { isFeatured = false } = options;

  // Coordonnées géographiques
  const latitude = item.location?.lat ?? item.lat ?? 0;
  const longitude = item.location?.lng ?? item.lng ?? 0;

  // Description : Apify ne fournit pas toujours une description.
  // On utilise categoryName comme fallback.
  const description = item.description
    || item.editorialSummary
    || item.categoryName
    || '';

  // Horaires
  const schedule = mapSchedule(item.openingHours);

  // Réseaux sociaux
  const socialMedia = item.socialMedia || {};

  return {
    nom: item.title || item.name || '',
    description,
    rating: typeof item.totalScore === 'number' ? item.totalScore : 0,
    latitude,
    longitude,
    photos: mapPhotos(item),
    prixRange: mapPrixRange(item.price),
    isFeatured,
    address: item.address || item.street || null,
    phone: item.phone || item.phoneUnformatted || null,
    email: item.email || null,
    website: item.website || null,
    facebookUrl: socialMedia.facebook || null,
    instagramUrl: socialMedia.instagram || null,
    tiktokUrl: socialMedia.tiktok || null,
    amenities: mapAmenities(item.additionalInfo),
    schedule,
    reviewCount: item.reviewsCount ?? null,
    distanceKm: null, // Calculé côté app Flutter
    // Métadonnées d'import (utiles pour audit / re-import)
    _source: 'apify',
    _apifyId: item.placeId || item.id || null,
    _importedAt: new Date().toISOString(),
  };
}

module.exports = { mapApifyItem };
