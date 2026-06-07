import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Notification messages in Arabic and French.
 */
const MESSAGES = {
  orderReceived: {
    ar: {
      title: "تم استلام ملابسك",
      body: (eta: string) => `تم استلام ملابسك - الموعد المتوقع: ${eta}`,
    },
    fr: {
      title: "Vêtements reçus",
      body: (eta: string) =>
        `Vos vêtements ont été reçus - Heure estimée: ${eta}`,
    },
  },
  orderWashing: {
    ar: {
      title: "بدأ غسيل ملابسك",
      body: "يتم الآن غسل ملابسك",
    },
    fr: {
      title: "Lavage commencé",
      body: "Vos vêtements sont en cours de lavage",
    },
  },
  orderReady: {
    ar: {
      title: "ملابسك جاهزة!",
      body: "ملابسك جاهزة! يمكنك استلامها الآن",
    },
    fr: {
      title: "Vêtements prêts !",
      body: "Vos vêtements sont prêts ! Vous pouvez les récupérer maintenant",
    },
  },
  orderDelivered: {
    ar: {
      title: "تم تسليم ملابسك",
      body: "تم تسليم ملابسك بنجاح. شكراً لك!",
    },
    fr: {
      title: "Vêtements livrés",
      body: "Vos vêtements ont été livrés avec succès. Merci !",
    },
  },
};

/**
 * Formats a Firestore Timestamp to a readable date/time string.
 */
function formatDateTime(timestamp: admin.firestore.Timestamp): string {
  const date = timestamp.toDate();
  const options: Intl.DateTimeFormatOptions = {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  };
  return date.toLocaleDateString("ar-MR", options);
}

/**
 * Sends a push notification to a specific user.
 */
async function sendNotificationToUser(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      functions.logger.warn(`User ${userId} not found`);
      return;
    }

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      functions.logger.warn(`No FCM token for user ${userId}`);
      return;
    }

    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title,
        body,
      },
      data: data || {},
      android: {
        priority: "high",
        notification: {
          channelId: "wawapp_orders",
          priority: "high",
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title,
              body,
            },
            badge: 1,
            sound: "default",
          },
        },
      },
    };

    await messaging.send(message);
    functions.logger.info(`Notification sent to user ${userId}: ${title}`);

    // Store notification in Firestore for history
    await db.collection("notifications").add({
      userId,
      title,
      body,
      data: data || {},
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    functions.logger.error(`Error sending notification to ${userId}:`, error);
  }
}

/**
 * Cloud Function triggered when an order document is created.
 * Sends a notification to the customer that their clothes have been received.
 */
export const onOrderCreated = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snapshot, context) => {
    const orderData = snapshot.data();
    const orderId = context.params.orderId;

    const customerId = orderData.customerId;
    const estimatedTime = orderData.estimatedCompletionTime;

    // Get customer's preferred language
    const customerDoc = await db.collection("users").doc(customerId).get();
    const lang = customerDoc.data()?.preferredLanguage || "ar";

    const eta = formatDateTime(estimatedTime);
    const messages = MESSAGES.orderReceived[lang as "ar" | "fr"] ||
      MESSAGES.orderReceived.ar;

    await sendNotificationToUser(
      customerId,
      messages.title,
      messages.body(eta),
      {
        type: "order_received",
        orderId,
      }
    );

    functions.logger.info(`Order created notification sent for order ${orderId}`);
  });

/**
 * Cloud Function triggered when an order document is updated.
 * Sends notifications based on status changes.
 */
export const onOrderUpdated = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const orderId = context.params.orderId;

    // Only proceed if status changed
    if (beforeData.status === afterData.status) {
      return;
    }

    const customerId = afterData.customerId;
    const newStatus = afterData.status;

    // Get customer's preferred language
    const customerDoc = await db.collection("users").doc(customerId).get();
    const lang = customerDoc.data()?.preferredLanguage || "ar";

    let title: string;
    let body: string;
    let notificationType: string;

    switch (newStatus) {
      case "washing": {
        const msgs = MESSAGES.orderWashing[lang as "ar" | "fr"] ||
          MESSAGES.orderWashing.ar;
        title = msgs.title;
        body = msgs.body;
        notificationType = "order_washing";
        break;
      }
      case "ready": {
        const msgs = MESSAGES.orderReady[lang as "ar" | "fr"] ||
          MESSAGES.orderReady.ar;
        title = msgs.title;
        body = msgs.body;
        notificationType = "order_ready";
        break;
      }
      case "delivered": {
        const msgs = MESSAGES.orderDelivered[lang as "ar" | "fr"] ||
          MESSAGES.orderDelivered.ar;
        title = msgs.title;
        body = msgs.body;
        notificationType = "order_delivered";
        break;
      }
      default:
        functions.logger.info(`No notification for status: ${newStatus}`);
        return;
    }

    await sendNotificationToUser(customerId, title, body, {
      type: notificationType,
      orderId,
    });

    functions.logger.info(
      `Status change notification sent for order ${orderId}: ${newStatus}`
    );
  });

/**
 * Cloud Function triggered when a new rating is added.
 * Can be used to notify the laundry owner about new ratings.
 */
export const onRatingCreated = functions.firestore
  .document("ratings/{ratingId}")
  .onCreate(async (snapshot) => {
    const ratingData = snapshot.data();
    const laundryId = ratingData.laundryId;
    const rating = ratingData.rating;

    // Notify laundry owner about new rating
    await sendNotificationToUser(
      laundryId,
      "تقييم جديد",
      `حصلت على تقييم ${rating}/5 نجوم`,
      {
        type: "new_rating",
        rating: rating.toString(),
      }
    );
  });

/**
 * Scheduled function to send reminders for orders that are overdue.
 * Runs every hour.
 */
export const checkOverdueOrders = functions.pubsub
  .schedule("every 60 minutes")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    // Find orders that are overdue (past estimated completion time)
    // and still in received/washing status
    const overdueOrders = await db
      .collection("orders")
      .where("status", "in", ["received", "washing"])
      .where("estimatedCompletionTime", "<", now)
      .get();

    for (const doc of overdueOrders.docs) {
      const orderData = doc.data();
      const laundryId = orderData.laundryId;

      // Notify laundry owner about overdue order
      await sendNotificationToUser(
        laundryId,
        "طلب متأخر!",
        `الطلب ${doc.id.substring(0, 6)} تجاوز الموعد المتوقع`,
        {
          type: "overdue_order",
          orderId: doc.id,
        }
      );
    }

    functions.logger.info(
      `Checked ${overdueOrders.size} overdue orders`
    );
  });

/**
 * HTTP function to clean up old FCM tokens (called periodically).
 */
export const cleanupInactiveTokens = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const inactiveUsers = await db
      .collection("users")
      .where("lastLoginAt", "<", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
      .get();

    let cleaned = 0;
    for (const doc of inactiveUsers.docs) {
      if (doc.data().fcmToken) {
        await doc.ref.update({ fcmToken: null });
        cleaned++;
      }
    }

    functions.logger.info(`Cleaned ${cleaned} inactive FCM tokens`);
  });
