package com.example.application_flutter;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.util.Log;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class PendingNotificationDatabase extends SQLiteOpenHelper {
    private static final String TAG = "PendingNotificationDB";
    private static final String DATABASE_NAME = "pending_notifications.db";
    private static final int DATABASE_VERSION = 1;

    private static final String TABLE_NAME = "pending_notifications";
    private static final String COLUMN_ID = "id";
    private static final String COLUMN_PACKAGE_NAME = "package_name";
    private static final String COLUMN_TITLE = "title";
    private static final String COLUMN_CONTENT = "content";
    private static final String COLUMN_TIMESTAMP = "timestamp";

    private static PendingNotificationDatabase instance;

    public static synchronized PendingNotificationDatabase getInstance(Context context) {
        if (instance == null) {
            instance = new PendingNotificationDatabase(context.getApplicationContext());
        }
        return instance;
    }

    private PendingNotificationDatabase(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        String createTable = "CREATE TABLE " + TABLE_NAME + " (" +
                COLUMN_ID + " INTEGER PRIMARY KEY AUTOINCREMENT, " +
                COLUMN_PACKAGE_NAME + " TEXT, " +
                COLUMN_TITLE + " TEXT, " +
                COLUMN_CONTENT + " TEXT, " +
                COLUMN_TIMESTAMP + " INTEGER" +
                ")";
        db.execSQL(createTable);
        Log.d(TAG, "Database table created");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        db.execSQL("DROP TABLE IF EXISTS " + TABLE_NAME);
        onCreate(db);
    }

    public long insertNotification(String packageName, String title, String content) {
        SQLiteDatabase db = this.getWritableDatabase();
        ContentValues values = new ContentValues();
        values.put(COLUMN_PACKAGE_NAME, packageName);
        values.put(COLUMN_TITLE, title);
        values.put(COLUMN_CONTENT, content);
        values.put(COLUMN_TIMESTAMP, System.currentTimeMillis());

        long id = db.insert(TABLE_NAME, null, values);
        Log.d(TAG, "Notification inserted with ID: " + id + " | Package: " + packageName);
        return id;
    }

    public List<Map<String, String>> getAllPending() {
        List<Map<String, String>> notifications = new ArrayList<>();
        SQLiteDatabase db = this.getReadableDatabase();

        Cursor cursor = db.query(
                TABLE_NAME,
                new String[] { COLUMN_ID, COLUMN_PACKAGE_NAME, COLUMN_TITLE, COLUMN_CONTENT, COLUMN_TIMESTAMP },
                null,
                null,
                null,
                null,
                COLUMN_TIMESTAMP + " ASC");

        if (cursor.moveToFirst()) {
            do {
                Map<String, String> notification = new HashMap<>();
                notification.put("id", cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_ID)));
                notification.put("packageName", cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_PACKAGE_NAME)));
                notification.put("title", cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_TITLE)));
                notification.put("content", cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_CONTENT)));
                notification.put("timestamp", cursor.getString(cursor.getColumnIndexOrThrow(COLUMN_TIMESTAMP)));
                notifications.add(notification);
            } while (cursor.moveToNext());
        }

        cursor.close();
        Log.d(TAG, "Retrieved " + notifications.size() + " pending notifications");
        return notifications;
    }

    public int deletePending(String id) {
        SQLiteDatabase db = this.getWritableDatabase();
        int rowsDeleted = db.delete(TABLE_NAME, COLUMN_ID + " = ?", new String[] { id });
        Log.d(TAG, "Deleted notification with ID: " + id);
        return rowsDeleted;
    }

    public int deleteAll() {
        SQLiteDatabase db = this.getWritableDatabase();
        int rowsDeleted = db.delete(TABLE_NAME, null, null);
        Log.d(TAG, "Deleted all " + rowsDeleted + " pending notifications");
        return rowsDeleted;
    }

    public int getPendingCount() {
        SQLiteDatabase db = this.getReadableDatabase();
        Cursor cursor = db.rawQuery("SELECT COUNT(*) FROM " + TABLE_NAME, null);
        int count = 0;
        if (cursor.moveToFirst()) {
            count = cursor.getInt(0);
        }
        cursor.close();
        return count;
    }
}
