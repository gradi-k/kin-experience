/**
 * Firebase Firestore Seeder (Method 1)
 * - Reads JSON arrays from ./seed_json/*.json
 * - Upserts docs into Firestore collections
 *
 * Usage:
 *  1) npm i firebase-admin
 *  2) export GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json
 *  3) node import_to_firestore.js
 */
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

const SEED_DIR = path.join(__dirname, "seed_json");

function readJson(file) {
  const p = path.join(SEED_DIR, file);
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

async function upsertCollection(collName, docs, idField = "id") {
  if (!Array.isArray(docs)) {
    console.warn(`[SKIP] ${collName}: not an array (maybe parse error).`);
    return;
  }
  console.log(`\n==> Importing ${collName}: ${docs.length} docs`);

  const batchSize = 400; // Firestore batch limit = 500
  for (let i = 0; i < docs.length; i += batchSize) {
    const slice = docs.slice(i, i + batchSize);
    const batch = db.batch();

    slice.forEach((doc) => {
      const id = (doc && doc[idField]) ? String(doc[idField]) : null;
      const ref = id ? db.collection(collName).doc(id) : db.collection(collName).doc();
      const payload = {
        ...doc,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      batch.set(ref, payload, { merge: true });
    });

    await batch.commit();
    console.log(`   - committed ${Math.min(i + batchSize, docs.length)}/${docs.length}`);
  }
}

async function main() {
  // Collections inferred from fake_data.dart
  const collections = [
    ["sites", "sites.json"],
    ["restos", "restos.json"],
    ["hotels", "hotels.json"],
    ["events", "events.json"],
    ["entreprises", "entreprises.json"],
    ["shoppings", "shoppings.json"],

    // Optional
    ["reels", "reels.json"],
    ["ads", "ads.json"],
  ];

  for (const [coll, file] of collections) {
    if (!fs.existsSync(path.join(SEED_DIR, file))) continue;
    const docs = readJson(file);

    // reels / ads might not have "id" in your fake files.
    // If no id, Firestore will auto-generate.
    const idField = ["sites","restos","hotels","events","entreprises","shoppings"].includes(coll) ? "id" : "id";
    await upsertCollection(coll, docs, idField);
  }

  console.log("\nDONE.");
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
