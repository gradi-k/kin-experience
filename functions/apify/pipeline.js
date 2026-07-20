/**
 * pipeline.js
 * Import automatisé de lieux depuis Apify (Google Places Crawler) vers la
 * collection unifiée `places`.
 *
 * `startApifyImport` (onCall) lance un run de l'actor Apify et enregistre un
 * webhook. `apifyWebhook` (onRequest) reçoit la fin du run, télécharge le
 * dataset et écrit les lieux en base (nouveaux lieux en brouillon).
 */
const {onCall, onRequest, HttpsError} =
  require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const {mapApifyItem} = require("./mapper");

const APIFY_TOKEN = defineSecret("APIFY_TOKEN");
const APIFY_WEBHOOK_SECRET = defineSecret("APIFY_WEBHOOK_SECRET");

const ACTOR_ID = "compass~crawler-google-places";
const APIFY_API = "https://api.apify.com/v2";

// Termes de recherche par catégorie (clés = collection `categories`).
const CATEGORY_SEARCH_TERMS = {
  restaurants: "restaurants",
  hotels: "hôtels",
  sites: "sites touristiques attractions",
  business: "entreprises services",
  shopping: "boutiques centres commerciaux",
};

/**
 * Vérifie que l'utilisateur authentifié est administrateur.
 * @param {?Object} auth `request.auth`.
 * @return {Promise<void>}
 */
async function assertIsAdmin(auth) {
  if (!auth) throw new HttpsError("unauthenticated", "Connexion requise");
  const snap = await admin.firestore().doc(`users/${auth.uid}`).get();
  const u = snap.data() || {};
  if (u.role !== "admin" && u.isAdmin !== true) {
    throw new HttpsError("permission-denied", "Réservé aux administrateurs");
  }
}

const startApifyImport = onCall(
    {secrets: [APIFY_TOKEN, APIFY_WEBHOOK_SECRET]},
    async (request) => {
      await assertIsAdmin(request.auth);

      const data = request.data || {};
      const categoryKey = data.categoryKey;
      const commune = data.commune;
      const customQuery = data.customQuery;
      const maxItems = Math.min(Number(data.maxItems) || 50, 200);

      if (!CATEGORY_SEARCH_TERMS[categoryKey]) {
        throw new HttpsError("invalid-argument",
            `Catégorie non supportée: ${categoryKey}`);
      }

      const query = (customQuery && String(customQuery).trim()) ||
          [CATEGORY_SEARCH_TERMS[categoryKey], commune, "Kinshasa"]
              .filter(Boolean).join(" ");

      const projectId = process.env.GCLOUD_PROJECT;
      const webhookUrl =
          `https://europe-west1-${projectId}.cloudfunctions.net/` +
          `apifyWebhook?secret=${APIFY_WEBHOOK_SECRET.value()}`;
      const webhooks = Buffer.from(JSON.stringify([{
        eventTypes: ["ACTOR.RUN.SUCCEEDED", "ACTOR.RUN.FAILED",
          "ACTOR.RUN.ABORTED", "ACTOR.RUN.TIMED_OUT"],
        requestUrl: webhookUrl,
      }])).toString("base64");

      const startUrl = `${APIFY_API}/acts/${ACTOR_ID}/runs` +
          `?token=${APIFY_TOKEN.value()}&webhooks=${webhooks}`;
      const res = await fetch(startUrl, {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          searchStringsArray: [query],
          locationQuery: "Kinshasa, Democratic Republic of the Congo",
          maxCrawledPlacesPerSearch: maxItems,
          language: "fr",
        }),
      });
      if (!res.ok) {
        throw new HttpsError("internal",
            `Apify a refusé le lancement (${res.status})`);
      }
      const body = await res.json();
      const run = body.data;

      await admin.firestore().doc(`apify_imports/${run.id}`).set({
        runId: run.id,
        categoryKey,
        query,
        commune: commune || null,
        maxItems,
        status: "running",
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
        startedBy: request.auth.uid,
        finishedAt: null,
        counts: null,
        error: null,
      });
      return {runId: run.id};
    });

/**
 * Écrit une page d'items mappés dans `places`, par lots.
 * @param {Array<Object>} items Items Apify bruts.
 * @param {string} categoryKey Catégorie du run.
 * @param {string} runId Identifiant du run.
 * @return {Promise<{created: number, updated: number, skipped: number}>}
 */
async function writeItemsBatch(items, categoryKey, runId) {
  const db = admin.firestore();
  const result = {created: 0, updated: 0, skipped: 0};

  let batch = db.batch();
  let ops = 0;

  for (const item of items) {
    const mapped = mapApifyItem(item, {categoryKey, runId});
    if (!mapped) {
      result.skipped++;
      continue;
    }

    const ref = db.collection("places").doc(mapped.docId);
    const existing = await ref.get();
    const now = admin.firestore.FieldValue.serverTimestamp();

    if (!existing.exists) {
      batch.set(ref, {
        ...mapped.data,
        isDraft: true,
        isFeatured: false,
        createdAt: now,
        updatedAt: now,
      });
      result.created++;
    } else {
      // Merge sans écraser isDraft/isFeatured, ni un champ existant par une
      // valeur Apify vide.
      const existingData = existing.data();
      const patch = {...mapped.data, updatedAt: now};
      for (const key of Object.keys(patch)) {
        const value = patch[key];
        const isEmpty = value === null || value === "" ||
            (Array.isArray(value) && value.length === 0);
        if (isEmpty && existingData[key] !== undefined &&
            existingData[key] !== null) {
          delete patch[key];
        }
      }
      batch.set(ref, patch, {merge: true});
      result.updated++;
    }

    if (++ops >= 400) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }

  if (ops > 0) await batch.commit();
  return result;
}

const apifyWebhook = onRequest(
    {secrets: [APIFY_TOKEN, APIFY_WEBHOOK_SECRET]},
    async (req, res) => {
      if (req.query.secret !== APIFY_WEBHOOK_SECRET.value()) {
        res.status(401).send("unauthorized");
        return;
      }

      const eventType = req.body && req.body.eventType;
      const run = req.body && req.body.resource;
      if (!run || !run.id) {
        res.status(400).send("payload invalide");
        return;
      }

      const db = admin.firestore();
      const trackRef = db.doc(`apify_imports/${run.id}`);
      const track = await trackRef.get();
      const trackData = track.data() || {};

      // Idempotence : Apify peut rejouer un webhook.
      if (trackData.status === "done" || trackData.status === "failed") {
        res.status(200).send("déjà traité");
        return;
      }

      if (eventType !== "ACTOR.RUN.SUCCEEDED") {
        await trackRef.set({
          status: "failed",
          error: `Run Apify: ${eventType}`,
          finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
        res.status(200).send("échec enregistré");
        return;
      }

      const categoryKey = trackData.categoryKey;
      if (!categoryKey) {
        await trackRef.set({
          status: "failed",
          error: "Run inconnu (pas de suivi)",
          finishedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
        res.status(200).send("run inconnu");
        return;
      }

      const counts = {fetched: 0, created: 0, updated: 0, skipped: 0};
      let offset = 0;
      const pageSize = 200;

      for (;;) {
        const pageUrl = `${APIFY_API}/datasets/${run.defaultDatasetId}` +
            `/items?token=${APIFY_TOKEN.value()}&clean=true` +
            `&offset=${offset}&limit=${pageSize}`;
        const pageRes = await fetch(pageUrl);
        const items = await pageRes.json();
        if (!Array.isArray(items) || items.length === 0) break;

        counts.fetched += items.length;
        const pageResult = await writeItemsBatch(items, categoryKey, run.id);
        counts.created += pageResult.created;
        counts.updated += pageResult.updated;
        counts.skipped += pageResult.skipped;

        if (items.length < pageSize) break;
        offset += pageSize;
      }

      await trackRef.set({
        status: "done",
        counts,
        finishedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      res.status(200).send("import terminé");
    });

module.exports = {startApifyImport, apifyWebhook};
