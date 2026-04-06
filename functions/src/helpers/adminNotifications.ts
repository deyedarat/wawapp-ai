/**
 * Helper: Write admin notification to Firestore
 * Used by Cloud Functions to create notifications for the Admin panel.
 */

import * as admin from 'firebase-admin';

export type AdminNotificationType =
  | 'new_order'
  | 'new_driver'
  | 'expired_order'
  | 'topup_request'
  | 'payout_request'
  | 'critical_delay';

interface AdminNotificationPayload {
  type: AdminNotificationType;
  title: string;
  body: string;
  data?: Record<string, string>;
}

/**
 * Writes a single notification document to /notifications for the admin user.
 * The Admin Flutter app listens to this collection with userId == 'admin'.
 * Non-blocking: errors are logged but do not throw.
 */
export async function writeAdminNotification(
  payload: AdminNotificationPayload
): Promise<void> {
  try {
    const docRef = await admin.firestore().collection('notifications').add({
      userId: 'admin',
      type: payload.type,
      title: payload.title,
      body: payload.body,
      data: payload.data ?? {},
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('[AdminNotifications] Notification written', {
      doc_id: docRef.id,
      type: payload.type,
    });
  } catch (error: any) {
    console.error('[AdminNotifications] Failed to write admin notification', {
      type: payload.type,
      error: error.message,
    });
    // Non-fatal: do not rethrow
  }
}
