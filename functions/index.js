const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

// Initialisation
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Configuration globale (Région par défaut)
setGlobalOptions({region: "europe-west1"});

/**
 * Helper pour envoyer une notification à tous les tokens FCM
 */
async function sendNotificationToAll(title, body, data = {}, imageUrl = null) {
  try {
    const tokensSnapshot = await db.collection("fcmTokens").get();
    if (tokensSnapshot.empty) {
      console.log("Aucun token FCM trouvé");
      return;
    }

    const tokens = tokensSnapshot.docs.map((doc) => doc.data().token).filter(Boolean);
    if (tokens.length === 0) return;

    const message = {
      notification: {title, body},
      data: {...data, click_action: "FLUTTER_NOTIFICATION_CLICK"},
      tokens,
    };

    if (imageUrl) message.notification.imageUrl = imageUrl;

    const response = await messaging.sendEachForMulticast(message);
    console.log(`Notifications envoyées: ${response.successCount} succès`);

    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) failedTokens.push(tokens[idx]);
      });
      for (const token of failedTokens) {
        await db.collection("fcmTokens").doc(token).delete();
      }
    }
    return response;
  } catch (error) {
    console.error("Erreur envoi notifications:", error);
    throw error;
  }
}

/**
 * Helpers pour enregistrer les notifications dans Firestore
 */
async function createGlobalNotification(title, body, category, itemId, imageUrl = null) {
  await db.collection("notifications").add({
    title, body, category, itemId, imageUrl,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    isGlobal: true,
  });
}

async function distributeToUsers(title, body, category, itemId, imageUrl = null) {
  const usersSnapshot = await db.collection("users").get();
  const batch = db.batch();
  usersSnapshot.docs.forEach((userDoc) => {
    const notifRef = db.collection("users").doc(userDoc.id).collection("notifications").doc();
    batch.set(notifRef, {
      title, body, category, itemId, imageUrl,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });
  });
  await batch.commit();
}

// ============================================================
// TRIGGERS FIRESTORE (V2)
// ============================================================

const createTrigger = (collection, emoji, label) => {
  return onDocumentCreated(`${collection}/{id}`, async (event) => {
    const data = event.data.data();
    const id = event.params.id;
    const name = data.nom || `Nouveau ${label}`;
    const imageUrl = data.photos && data.photos.length > 0 ? data.photos[0] : null;

    const title = `${emoji} Nouveau ${label} ajouté !`;
    const body = `Découvrez "${name}" dans ${label}s`;

    await sendNotificationToAll(title, body, {category: collection, itemId: id}, imageUrl);
    await createGlobalNotification(title, body, collection, id, imageUrl);
    await distributeToUsers(title, body, collection, id, imageUrl);
  });
};

exports.onNewSite = createTrigger("sites", "🏛️", "site");
exports.onNewRestaurant = createTrigger("restaurants", "🍽️", "restaurant");
exports.onNewHotel = createTrigger("hotels", "🏨", "hôtel");
exports.onNewEvent = createTrigger("events", "🎉", "événement");
exports.onNewEntreprise = createTrigger("entreprises", "🏢", "entreprise");
exports.onNewShopping = createTrigger("shoppings", "🛍️", "shopping");

// ============================================================
// FONCTION APPELABLE (V2)
// ============================================================

exports.sendCustomNotification = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentification requise");
  }

  const userDoc = await db.collection("users").doc(request.auth.uid).get();
  const userData = userDoc.data();

  if (!userData || (userData.role !== "admin" && !userData.isAdmin)) {
    throw new HttpsError("permission-denied", "Droits admin requis");
  }

  const {title, body, category, itemId, imageUrl} = request.data;

  try {
    await sendNotificationToAll(title, body, {
      category: category || "",
      itemId: itemId || "",
    }, imageUrl);

    if (category && itemId) {
      await createGlobalNotification(title, body, category, itemId, imageUrl);
      await distributeToUsers(title, body, category, itemId, imageUrl);
    }

    return {success: true};
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});

// ============================================================
// NETTOYAGE (V2)
// ============================================================

exports.cleanupOldNotifications = onSchedule("0 0 * * *", async (event) => {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const oldNotifs = await db.collection("notifications")
      .where("timestamp", "<", thirtyDaysAgo).get();

  const batch = db.batch();
  oldNotifs.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  console.log("Nettoyage terminé");
});