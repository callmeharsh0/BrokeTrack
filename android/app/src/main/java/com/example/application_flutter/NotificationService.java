package com.example.application_flutter;

import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.content.Intent;
import android.util.Log;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

public class NotificationService extends NotificationListenerService {
    private static final String TAG = "NotificationService";
    public static final String NOTIFICATION_EVENT = "notification_event";

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        super.onNotificationPosted(sbn);

        try {
            String packageName = sbn.getPackageName();
            String title = "";
            String content = "";

            if (sbn.getNotification() != null && sbn.getNotification().extras != null) {
                title = sbn.getNotification().extras.getString("android.title", "");
                content = sbn.getNotification().extras.getString("android.text", "");
            }

            Log.d(TAG, "Notification Posted - Package: " + packageName);
            Log.d(TAG, "Title: " + title + ", Content: " + content);

            // ALWAYS persist to database first (works even when app is closed)
            PendingNotificationDatabase db = PendingNotificationDatabase.getInstance(this);
            long insertId = db.insertNotification(packageName, title, content);
            Log.d(TAG, "Persisted to database with ID: " + insertId);

            // ALSO try to send to Flutter via EventChannel (only works when app is running)
            Intent intent = new Intent(NOTIFICATION_EVENT);
            intent.putExtra("packageName", packageName);
            intent.putExtra("title", title);
            intent.putExtra("content", content);
            LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
            Log.d(TAG, "Broadcast sent to Flutter (if app is running)");

        } catch (Exception e) {
            Log.e(TAG, "Error processing notification: " + e.getMessage());
        }
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        super.onNotificationRemoved(sbn);
    }

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        Log.d(TAG, "Notification Listener Connected");
    }

    @Override
    public void onListenerDisconnected() {
        super.onListenerDisconnected();
        Log.d(TAG, "Notification Listener Disconnected");
        requestRebind(null);
    }
}