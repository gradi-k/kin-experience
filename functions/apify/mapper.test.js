const test = require("node:test");
const assert = require("node:assert");
const {mapApifyItem} = require("./mapper");

const fullItem = {
  placeId: "ChIJabc123",
  title: "Chez Ntemba",
  description: "Grill réputé",
  categoryName: "Restaurant",
  totalScore: 4.4,
  reviewsCount: 120,
  location: {lat: -4.30, lng: 15.29},
  imageUrls: ["https://a.jpg", "https://b.jpg", "https://c.jpg",
    "https://d.jpg", "https://e.jpg", "https://f.jpg"],
  price: "$$",
  address: "Av. du Port, Gombe",
  phone: "+243 81 000 0000",
  website: "https://ntemba.cd",
  openingHours: [{day: "Monday", hours: "9AM–10PM"}],
  socialMedia: {facebook: "https://fb.com/ntemba"},
  additionalInfo: {"Options": [{"Terrasse": true}, {"Wifi": false}]},
};

test("item complet mappé vers le format Place", () => {
  const out = mapApifyItem(fullItem, {categoryKey: "restaurants", runId: "r1"});
  assert.strictEqual(out.docId, "ChIJabc123");
  const d = out.data;
  assert.strictEqual(d.nom, "Chez Ntemba");
  assert.strictEqual(d.categoryKey, "restaurants");
  assert.strictEqual(d.rating, 4.4);
  assert.strictEqual(d.latitude, -4.30);
  assert.strictEqual(d.longitude, 15.29);
  assert.strictEqual(d.photos.length, 5); // plafonné à 5
  assert.strictEqual(d.prixRange, "Modéré");
  assert.deepStrictEqual(d.amenities, ["Terrasse"]); // false exclu
  assert.strictEqual(d.schedule, "Monday: 9AM–10PM");
  assert.strictEqual(d.reviewCount, 120);
  assert.strictEqual(d.facebookUrl, "https://fb.com/ntemba");
  assert.strictEqual(d.source, "apify");
  assert.strictEqual(d.sourcePlaceId, "ChIJabc123");
  assert.strictEqual(d.importRunId, "r1");
  assert.strictEqual(d.isDraft, undefined); // décidé à l'écriture
});

test("item minimal accepté, description = categoryName", () => {
  const out = mapApifyItem(
      {placeId: "x", title: "Spot", categoryName: "Bar",
        location: {lat: 1, lng: 2}},
      {categoryKey: "restaurants", runId: "r1"});
  assert.strictEqual(out.data.description, "Bar");
  assert.strictEqual(out.data.rating, 0);
  assert.strictEqual(out.data.reviewCount, 0);
});

test("item sans GPS ou sans nom => null", () => {
  assert.strictEqual(mapApifyItem({title: "SansGPS", placeId: "y"},
      {categoryKey: "restaurants", runId: "r1"}), null);
  assert.strictEqual(mapApifyItem({location: {lat: 1, lng: 2}, placeId: "z"},
      {categoryKey: "restaurants", runId: "r1"}), null);
});

test("item sans placeId => null (pas d'ID de doc stable)", () => {
  assert.strictEqual(mapApifyItem({title: "X", location: {lat: 1, lng: 2}},
      {categoryKey: "restaurants", runId: "r1"}), null);
});
