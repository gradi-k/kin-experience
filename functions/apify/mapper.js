/**
 * mapper.js
 * Transforme un item brut du Google Places Crawler (Apify) vers le format
 * de la collection unifiée `places` de l'app (modèle Place).
 *
 * Un item sans placeId, sans nom ou sans coordonnées GPS est rejeté (null) :
 * le placeId sert d'ID de document (dédoublonnage entre runs) et un lieu
 * sans nom ou sans position est inutilisable dans l'app.
 */

/**
 * Convertit le champ "price" Apify ("$".."$$$$") vers le prixRange de l'app.
 * @param {string} price Prix Apify.
 * @return {string} Libellé prixRange.
 */
function mapPrixRange(price) {
  if (!price) return "";
  const map = {
    "$": "Bon marché",
    "$$": "Modéré",
    "$$$": "Cher",
    "$$$$": "Très cher",
  };
  return map[price] || price;
}

/**
 * Convertit les openingHours Apify vers une chaîne lisible.
 * @param {Array} openingHours [{day, hours}, ...].
 * @return {?string} Horaires ou null.
 */
function mapSchedule(openingHours) {
  if (!Array.isArray(openingHours) || openingHours.length === 0) return null;
  return openingHours.map((h) => `${h.day}: ${h.hours}`).join(" | ");
}

/**
 * Extrait les URLs de photos (max 5).
 * @param {Object} item Item Apify.
 * @return {Array<string>} URLs.
 */
function mapPhotos(item) {
  const urls = item.imageUrls || item.images || [];
  return urls
      .filter((u) => typeof u === "string" && u.startsWith("http"))
      .slice(0, 5);
}

/**
 * Extrait les équipements depuis additionalInfo.
 * @param {Object} additionalInfo Groupes Apify.
 * @return {Array<string>} Équipements actifs.
 */
function mapAmenities(additionalInfo) {
  if (!additionalInfo || typeof additionalInfo !== "object") return [];
  const result = [];
  for (const items of Object.values(additionalInfo)) {
    if (!Array.isArray(items)) continue;
    for (const entry of items) {
      if (typeof entry === "object" && entry !== null) {
        for (const [key, val] of Object.entries(entry)) {
          if (val === true) result.push(key);
        }
      } else if (typeof entry === "string") {
        result.push(entry);
      }
    }
  }
  return result;
}

/**
 * Transforme un item Apify en document `places`.
 * @param {Object} item Item brut Apify.
 * @param {Object} options {categoryKey, runId}.
 * @return {?{docId: string, data: Object}} Doc prêt, ou null si invalide.
 */
function mapApifyItem(item, {categoryKey, runId}) {
  const docId = item.placeId || null;
  const nom = item.title || item.name || "";
  const location = item.location || {};
  const latitude = location.lat || item.lat || 0;
  const longitude = location.lng || item.lng || 0;

  if (!docId || !nom || (latitude === 0 && longitude === 0)) return null;

  const description = item.description ||
      item.editorialSummary ||
      item.categoryName ||
      "";
  const socialMedia = item.socialMedia || {};

  return {
    docId,
    data: {
      categoryKey,
      nom,
      description,
      rating: typeof item.totalScore === "number" ? item.totalScore : 0,
      latitude,
      longitude,
      photos: mapPhotos(item),
      prixRange: mapPrixRange(item.price),
      address: item.address || item.street || null,
      phone: item.phone || item.phoneUnformatted || null,
      email: item.email || null,
      website: item.website || null,
      facebookUrl: socialMedia.facebook || null,
      instagramUrl: socialMedia.instagram || null,
      tiktokUrl: socialMedia.tiktok || null,
      amenities: mapAmenities(item.additionalInfo),
      schedule: mapSchedule(item.openingHours),
      reviewCount: typeof item.reviewsCount === "number" ?
        item.reviewsCount : 0,
      source: "apify",
      sourcePlaceId: docId,
      importRunId: runId,
    },
  };
}

module.exports = {mapApifyItem};
