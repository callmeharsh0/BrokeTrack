package com.example.application_flutter;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.provider.Settings;
import androidx.annotation.NonNull;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class NotificationPlugin implements FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private static final String METHOD_CHANNEL = "notification_plugin/methods";
    private static final String EVENT_CHANNEL = "notification_plugin/events";

    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private Context context;
    private EventChannel.EventSink eventSink;
    private BroadcastReceiver notificationReceiver;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();

        methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
        methodChannel.setMethodCallHandler(this);

        eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "isPermissionGranted":
                result.success(isNotificationServiceEnabled());
                break;
            case "requestPermission":
                openNotificationSettings();
                result.success(null);
                break;
            case "getPendingNotifications":
                getPendingNotifications(result);
                break;
            case "clearPendingNotifications":
                clearPendingNotifications(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void getPendingNotifications(Result result) {
        try {
            PendingNotificationDatabase db = PendingNotificationDatabase.getInstance(context);
            List<Map<String, String>> pendingNotifications = db.getAllPending();
            result.success(pendingNotifications);
        } catch (Exception e) {
            result.error("GET_PENDING_ERROR", "Failed to get pending notifications: " + e.getMessage(), null);
        }
    }

    private void clearPendingNotifications(Result result) {
        try {
            PendingNotificationDatabase db = PendingNotificationDatabase.getInstance(context);
            int deletedCount = db.deleteAll();
            result.success(deletedCount);
        } catch (Exception e) {
            result.error("CLEAR_PENDING_ERROR", "Failed to clear pending notifications: " + e.getMessage(), null);
        }
    }

    private boolean isNotificationServiceEnabled() {
        String pkgName = context.getPackageName();
        final String flat = Settings.Secure.getString(
                context.getContentResolver(),
                "enabled_notification_listeners");
        if (flat != null && !flat.isEmpty()) {
            final String[] names = flat.split(":");
            for (String name : names) {
                if (name.contains(pkgName)) {
                    return true;
                }
            }
        }
        return false;
    }

    private void openNotificationSettings() {
        Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        eventSink = events;

        notificationReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                String packageName = intent.getStringExtra("packageName");
                String title = intent.getStringExtra("title");
                String content = intent.getStringExtra("content");

                Map<String, String> data = new HashMap<>();
                data.put("packageName", packageName);
                data.put("title", title);
                data.put("content", content);

                if (eventSink != null) {
                    eventSink.success(data);
                }
            }
        };

        LocalBroadcastManager.getInstance(context).registerReceiver(
                notificationReceiver,
                new IntentFilter(NotificationService.NOTIFICATION_EVENT));
    }

    @Override
    public void onCancel(Object arguments) {
        if (notificationReceiver != null) {
            LocalBroadcastManager.getInstance(context).unregisterReceiver(notificationReceiver);
            notificationReceiver = null;
        }
        eventSink = null;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        methodChannel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
    }
}