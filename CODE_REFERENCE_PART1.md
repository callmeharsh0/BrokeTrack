# Complete Code Reference Guide
# AI Expense Tracker - Line-by-Line Documentation

This document provides detailed explanations for every code file in the project.

---

## Table of Contents

1. [Gradle Configuration Files](#gradle-configuration-files)
2. [Android Native Code](#android-native-code)
3. [Flutter Dart Code](#flutter-dart-code)
4. [Asset Files](#asset-files)

---

## 1. Gradle Configuration Files

### 1.1 Root `build.gradle.kts`
**Location**: `/android/build.gradle.kts`

```kotlin
// Lines 1-6: Configure repositories for all projects
allprojects {
    repositories {
        google()        // Google's Maven repository (Android plugins, AndroidX)
        mavenCentral()  // Central Maven repository (third-party libraries)
    }
}

// Lines 8-12: Redirect build output to parent directory
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")  // Build files go to project root /build
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Lines 14-17: Apply build directory to all subprojects
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Lines 18-20: Ensure app module is evaluated first
subprojects {
    project.evaluationDependsOn(":app")
}

// Lines 22-24: Define clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)  // Delete build directory
}
```

**Key Points**:
- **google()**: Required for AndroidX, Material Components
- **mavenCentral()**: Required for TensorFlow Lite, Kotlin libraries
- **Build directory redirect**: Keeps builds organized in Flutter project structure

---

### 1.2 `settings.gradle.kts`
**Location**: `/android/settings.gradle.kts`

```kotlin
// Lines 1-18: Plugin management configuration
pluginManagement {
    // Lines 2-9: Load Flutter SDK path from local.properties
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    // Line 11: Include Flutter's Gradle plugin
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    // Lines 13-17: Configure plugin repositories
    repositories {
        google()              // Android Gradle Plugin
        mavenCentral()        // Kotlin plugin
        gradlePluginPortal()  // Community plugins
    }
}

// Lines 20-24: Apply required plugins
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"  // Flutter plugin loader
    id("com.android.application") version "8.9.1" apply false  // Android app plugin
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false  // Kotlin support
}

// Line 26: Include app module
include(":app")  // Includes the /app subdirectory as a module
```

**Key Points**:
- **local.properties**: Contains Flutter SDK path (auto-generated)
- **flutter-plugin-loader**: Loads Flutter plugins defined in pubspec.yaml
- **apply false**: Plugins applied in app/build.gradle.kts instead

---

### 1.3 App `build.gradle.kts`
**Location**: `/android/app/build.gradle.kts`

```kotlin
// Lines 1-5: Apply plugins
plugins {
    id("com.android.application")           // Android app plugin
    id("kotlin-android")                    // Kotlin support
    id("dev.flutter.flutter-gradle-plugin")  // Flutter integration
}

// Lines 7-44: Android configuration
android {
    // Line 8: Package name (must match MainActivity.kt package)
    namespace = "com.example.application_flutter"
    
    // Line 9: Compile against Android API 36 (Android 16)
    compileSdk = 36
    
    // Line 10: NDK version for native code (if needed)
    ndkVersion = "27.0.12077973"

    // Lines 12-19: App configuration
    defaultConfig {
        applicationId = "com.example.application_flutter"  // Unique app ID
        minSdk = flutter.minSdkVersion  // Minimum Android version (21 = Android 5.0)
        targetSdk = 36                  // Target Android API (latest)
        versionCode = 1                 // Internal version number (increment for updates)
        versionName = "1.0.0"           // User-visible version string
        multiDexEnabled = true          // Support for 64K+ methods (required for large apps)
    }

    // Lines 21-24: Java compilation settings
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11  // Java 11 source
        targetCompatibility = JavaVersion.VERSION_11  // Java 11 bytecode
    }

    // Lines 26-28: Kotlin compilation settings
    kotlinOptions {
        jvmTarget = "11"  // Kotlin compiles to Java 11 bytecode
    }

    // Lines 30-43: Build types (debug vs release)
    buildTypes {
        getByName("debug") {
            // Default debug configuration (no optimizations)
        }
        getByName("release") {
            isMinifyEnabled = true        // Enable code shrinking
            isShrinkResources = true      // Remove unused resources
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"      // Custom ProGuard rules
            )
            signingConfig = signingConfigs.getByName("debug")  // Use debug key for now
        }
    }
}

// Lines 46-55: Dependencies
dependencies {
    // Line 48: TensorFlow Lite for ML model inference
    implementation("org.tensorflow:tensorflow-lite:2.12.0")
    
    // Line 51: LocalBroadcastManager for cross-process communication
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")

    // Line 54: Kotlin standard library
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.10")
}

// Lines 57-59: Flutter configuration
flutter {
    source = "../.."  // Points to Flutter project root
}
```

**Key Points**:
- **minSdk = 21**: Supports 99%+ Android devices
- **multiDexEnabled**: Required because app has >64K methods (TFLite + Flutter)
- **isMinifyEnabled**: Reduces APK size by 30-40%
- **tensorflow-lite:2.12.0**: Specific version compatible with our model

**Why these versions?**
- **compileSdk 36**: Latest features and security patches
- **targetSdk 36**: Required by Google Play (must target recent API)
- **Java 11**: Required by Flutter 3.x and modern Android tools

---

## 2. Android Native Code

### 2.1 `NotificationService.java`
**Location**: `/android/app/src/main/java/.../NotificationService.java`

```java
// Lines 1-7: Package and imports
package com.example.application_flutter;

import android.service.notification.NotificationListenerService;  // Base class
import android.service.notification.StatusBarNotification;       // Notification object
import android.content.Intent;                                  // For broadcasts
import android.util.Log;                                        // Logging
import androidx.localbroadcastmanager.content.LocalBroadcastManager;  // IPC

// Lines 9-11: Class definition and constants
public class NotificationService extends NotificationListenerService {
    private static final String TAG = "NotificationService";  // Log tag
    public static final String NOTIFICATION_EVENT = "notification_event";  // Broadcast action

    // Lines 13-40: Main notification handler
    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        super.onNotificationPosted(sbn);  // Call parent implementation
        
        try {
            // Line 18: Extract package name (e.g., "com.google.android.apps.nbu.paisa.user")
            String packageName = sbn.getPackageName();
            String title = "";
            String content = "";
            
            // Lines 22-25: Extract notification text
            if (sbn.getNotification() != null && sbn.getNotification().extras != null) {
                title = sbn.getNotification().extras.getString("android.title", "");
                content = sbn.getNotification().extras.getString("android.text", "");
            }
            
            // Lines 27-28: Log for debugging
            Log.d(TAG, "Notification Posted - Package: " + packageName);
            Log.d(TAG, "Title: " + title + ", Content: " + content);
            
            // Lines 30-35: Send to Flutter via LocalBroadcastManager
            Intent intent = new Intent(NOTIFICATION_EVENT);  // Create broadcast intent
            intent.putExtra("packageName", packageName);     // Add package name
            intent.putExtra("title", title);                 // Add title
            intent.putExtra("content", content);             // Add content
            LocalBroadcastManager.getInstance(this).sendBroadcast(intent);
            
        } catch (Exception e) {
            // Line 37-39: Error handling
            Log.e(TAG, "Error processing notification: " + e.getMessage());
        }
    }

    // Lines 42-45: Notification removal handler (optional)
    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        super.onNotificationRemoved(sbn);
        // Could track when notifications are dismissed
    }

    // Lines 47-51: Service connection callback
    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        Log.d(TAG, "Notification Listener Connected");  // Service is active
    }

    // Lines 53-58: Service disconnection callback
    @Override
    public void onListenerDisconnected() {
        super.onListenerDisconnected();
        Log.d(TAG, "Notification Listener Disconnected");
        requestRebind(null);  // Request Android to restart service
    }
}
```

**Key Concepts**:

1. **NotificationListenerService**:
   - System service that runs independently of app
   - Survives app closure
   - Requires special permission from user

2. **LocalBroadcastManager**:
   - Sends broadcasts within same app only (secure)
   - Doesn't require permissions
   - Alternative to EventBus or static callbacks

3. **Why two methods (onNotificationPosted + broadcast)?**
   - `onNotificationPosted`: Runs in service process
   - Broadcast: Sends data to Flutter (app process)
   - Two separate processes need IPC (Inter-Process Communication)

4. **requestRebind**:
   - If service crashes, asks Android to restart it
   - Improves reliability

---

### 2.2 `NotificationPlugin.java`
**Location**: `/android/app/src/main/java/.../NotificationPlugin.java`

```java
// Lines 1-17: Package and imports
package com.example.application_flutter;

import android.content.BroadcastReceiver;   // Receives broadcasts
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.provider.Settings;            // System settings
import androidx.annotation.NonNull;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import io.flutter.embedding.engine.plugins.FlutterPlugin;  // Flutter plugin interface
import io.flutter.plugin.common.EventChannel;              // Stream events to Flutter
import io.flutter.plugin.common.MethodChannel;             // Call methods from Flutter
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import java.util.HashMap;
import java.util.Map;

// Lines 19-27: Class definition and channel names
public class NotificationPlugin implements FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    // Channel names MUST match Dart code
    private static final String METHOD_CHANNEL = "notification_plugin/methods";
    private static final String EVENT_CHANNEL = "notification_plugin/events";
    
    private MethodChannel methodChannel;           // For method calls
    private EventChannel eventChannel;             // For event streaming
    private Context context;                       // Android context
    private EventChannel.EventSink eventSink;      // Stream events to Flutter
    private BroadcastReceiver notificationReceiver;  // Receives broadcasts

    // Lines 29-38: Plugin initialization
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();  // Save context
        
        // Create method channel (Dart calls Java)
        methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
        methodChannel.setMethodCallHandler(this);  // Handle method calls
        
        // Create event channel (Java streams to Dart)
        eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler(this);  // Handle stream lifecycle
    }

    // Lines 40-54: Handle method calls from Flutter
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "isPermissionGranted":
                // Check if notification access is granted
                result.success(isNotificationServiceEnabled());
                break;
            case "requestPermission":
                // Open system settings to grant permission
                openNotificationSettings();
                result.success(null);
                break;
            default:
                result.notImplemented();  // Method not found
                break;
        }
    }

    // Lines 56-71: Check if notification permission is granted
    private boolean isNotificationServiceEnabled() {
        String pkgName = context.getPackageName();  // Get app package name
        
        // Query system for enabled notification listeners
        final String flat = Settings.Secure.getString(
            context.getContentResolver(),
            "enabled_notification_listeners"  // System setting key
        );
        
        // Parse colon-separated list of enabled services
        if (flat != null && !flat.isEmpty()) {
            final String[] names = flat.split(":");
            for (String name : names) {
                if (name.contains(pkgName)) {  // Check if our app is in list
                    return true;
                }
            }
        }
        return false;
    }

    // Lines 73-77: Open notification settings
    private void openNotificationSettings() {
        Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);  // Start new task
        context.startActivity(intent);                   // Open settings
    }

    // Lines 79-105: Start event stream
    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        eventSink = events;  // Save event sink to send events later
        
        // Lines 83-99: Create broadcast receiver
        notificationReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                // Extract data from broadcast
                String packageName = intent.getStringExtra("packageName");
                String title = intent.getStringExtra("title");
                String content = intent.getStringExtra("content");
                
                // Create map for Flutter
                Map<String, String> data = new HashMap<>();
                data.put("packageName", packageName);
                data.put("title", title);
                data.put("content", content);
                
                // Send to Flutter via event sink
                if (eventSink != null) {
                    eventSink.success(data);  // Stream event to Dart
                }
            }
        };
        
        // Lines 101-104: Register broadcast receiver
        LocalBroadcastManager.getInstance(context).registerReceiver(
            notificationReceiver,
            new IntentFilter(NotificationService.NOTIFICATION_EVENT)  // Listen for this action
        );
    }

    // Lines 107-114: Stop event stream
    @Override
    public void onCancel(Object arguments) {
        if (notificationReceiver != null) {
            // Unregister receiver to prevent memory leaks
            LocalBroadcastManager.getInstance(context).unregisterReceiver(notificationReceiver);
            notificationReceiver = null;
        }
        eventSink = null;  // Clear event sink
    }

    // Lines 116-120: Plugin cleanup
    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        methodChannel.setMethodCallHandler(null);  // Remove handler
        eventChannel.setStreamHandler(null);       // Remove handler
    }
}
```

**Key Concepts**:

1. **MethodChannel**:
   - Flutter → Java (request-response)
   - Example: `platform.invokeMethod('isPermissionGranted')`

2. **EventChannel**:
   - Java → Flutter (continuous stream)
   - Example: `eventChannel.receiveBroadcastStream().listen()`

3. **BroadcastReceiver**:
   - Receives broadcasts from NotificationService
   - Forwards to Flutter via EventSink

4. **Flow Diagram**:
   ```
   NotificationService → Broadcast → NotificationPlugin → EventSink → Flutter
   ```

---

### 2.3 `AndroidManifest.xml`
**Location**: `/android/app/src/main/AndroidManifest.xml`

```xml
<!-- Lines 1-2: Root manifest -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.application_flutter">

    <!-- Lines 4-42: Application configuration -->
    <application
        android:label="AI Expense Tracker"  <!-- App name in launcher -->
        android:name="${applicationName}"   <!-- Flutter application class -->
        android:icon="@mipmap/ic_launcher"> <!-- App icon -->

        <!-- Lines 9-18: Notification service registration -->
        <service
            android:name=".NotificationService"  <!-- Service class -->
            android:label="AI Expense Tracker"   <!-- Service label -->
            android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"  <!-- Required permission -->
            android:exported="true">  <!-- Allows system to bind to service -->
            <intent-filter>
                <!-- Declares this as a notification listener service -->
                <action android:name="android.service.notification.NotificationListenerService" />
            </intent-filter>
        </service>

        <!-- Lines 20-37: Main activity (Flutter UI) -->
        <activity
            android:name=".MainActivity"
            android:exported="true"     <!-- Allows launcher to start -->
            android:launchMode="singleTop"  <!-- Reuse existing instance -->
            android:theme="@style/LaunchTheme"  <!-- Splash screen theme -->
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize..."
            android:hardwareAccelerated="true"  <!-- GPU acceleration -->
            android:windowSoftInputMode="adjustResize">  <!-- Keyboard behavior -->

            <!-- Lines 29-32: Launcher intent filter -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>

            <!-- Lines 34-36: Theme metadata -->
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
        </activity>

        <!-- Lines 39-41: Flutter metadata -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />  <!-- Flutter embedding version 2 -->
    </application>

    <!-- Lines 44-49: Queries for intent filters -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>

</manifest>
```

**Key Points**:
- **exported="true"**: Required for system binding
- **BIND_NOTIFICATION_LISTENER_SERVICE**: System permission (user must grant manually)
- **launchMode="singleTop"**: Prevents multiple instances
- **flutterEmbedding=2**: Uses modern Flutter embedding

---

## 3. Flutter Dart Code

### 3.1 `expense_model.dart`
**Location**: `/lib/expense_model.dart`

```dart
// Lines 1-8: Class definition with fields
class Expense {
  final int? id;          // Nullable: null for new expenses, int after DB insert
  final String title;     // Merchant name (e.g., "Zomato")
  final double amount;    // Transaction amount (e.g., 250.50)
  final DateTime date;    // Transaction timestamp
  final String category;  // Category ID (e.g., "food", "transport")
  final String type;      // "debit" or "credit"
  final String bankName;  // Bank/UPI source (e.g., "phonepe", "hdfc")

  // Lines 10-18: Constructor
  Expense({
    this.id,                    // Optional (null for new expenses)
    required this.title,        // Required
    required this.amount,       // Required
    required this.date,         // Required
    required this.category,     // Required
    required this.type,         // Required
    required this.bankName,     // Required
  });

  // Lines 20-35: Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,                           // Will be null for new expenses
      'title': title,                     // String as-is
      'amount': amount,                   // double as-is (SQLite supports REAL)
      'date': date.millisecondsSinceEpoch,  // DateTime → int (Unix timestamp)
      'category': category,               // String as-is
      'type': type,                       // String as-is
      'bankName': bankName,               // String as-is
    };
  }

  // Lines 37-50: Convert from Map (database result)
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],             // int or null
      title: map['title'],       // String
      amount: map['amount'],     // double (SQLite REAL)
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),  // int → DateTime
      category: map['category'], // String
      type: map['type'],         // String
      bankName: map['bankName'], // String
    );
  }

  // Lines 52-55: Debug string representation
  @override
  String toString() {
    return 'Expense{id: $id, title: $title, amount: $amount, date: $date, '
           'category: $category, type: $type, bankName: $bankName}';
  }
}
```

**Key Concepts**:

1. **Why `final` fields?**
   - Immutable objects (can't be modified after creation)
   - Thread-safe for async operations
   - Matches Flutter's philosophy

2. **Why `int?` for id?**
   - New expenses don't have ID yet
   - Database assigns ID during insert (auto-increment)
   - After insert, copy expense with new ID

3. **DateTime storage**:
   - SQLite doesn't have DATE type
   - Store as INTEGER (milliseconds since epoch)
   - Easy sorting and calculations

4. **Usage example**:
   ```dart
   // Create new expense (no ID)
   var expense = Expense(
     title: 'Zomato',
     amount: 250.50,
     date: DateTime.now(),
     category: 'food',
     type: 'debit',
     bankName: 'phonepe',
   );
   
   // Insert to database
   await db.insert('expenses', expense.toMap());
   
   // Read from database
   var maps = await db.query('expenses');
   List<Expense> expenses = maps.map((m) => Expense.fromMap(m)).toList();
   ```

---

### 3.2 `database_helper.dart`
**Location**: `/lib/database_helper.dart`

```dart
// Lines 1-5: Imports
import 'dart:io';                      // For Platform, Directory
import 'package:path/path.dart';       // For join() - path manipulation
import 'package:sqflite/sqflite.dart'; // SQLite database
import 'package:path_provider/path_provider.dart';  // Get app directory
import 'expense_model.dart';           // Expense model

// Lines 7-18: Singleton pattern
class DatabaseHelper {
  // Line 10: Private constructor
  DatabaseHelper._privateConstructor();
  
  // Line 11: Single instance
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Lines 13-18: Database instance (lazy initialization)
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;  // Return existing
    _database = await _initDatabase();         // Initialize on first access
    return _database!;
  }

  // Lines 20-30: Initialize database
  _initDatabase() async {
    // Get app documents directory (private to app)
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    
    // Create database path
    String path = join(documentsDirectory.path, 'expense_tracker.db');
    
    // Open database (creates if doesn't exist)
    return await openDatabase(
      path,
      version: 1,              // Schema version
      onCreate: _onCreate,     // Called on first creation
    );
  }

  // Lines 32-47: Create table schema
  Future _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,  -- Auto-increment ID
      title TEXT NOT NULL,                   -- Merchant name
      amount REAL NOT NULL,                  -- Double precision
      date INTEGER NOT NULL,                 -- Unix timestamp
      category TEXT NOT NULL,                -- Category ID
      type TEXT NOT NULL DEFAULT 'debit',    -- Transaction type
      bankName TEXT NOT NULL DEFAULT 'Unknown'  -- Bank name
    )
    ''');
  }

  // Lines 49-76: Insert with duplicate check
  Future<bool> insertExpense(Expense expense) async {
    final db = await instance.database;

    // Lines 55-65: Check for duplicate
    var existing = await db.query(
      'expenses',
      where: 'title = ? AND amount = ? AND date = ?',  // Composite key
      whereArgs: [
        expense.title,
        expense.amount,
        expense.date.millisecondsSinceEpoch
      ],
    );

    // Lines 67-75: Insert if not duplicate
    if (existing.isEmpty) {
      await db.insert('expenses', expense.toMap());  // Insert new row
      print('DatabaseHelper: Inserted new expense: ${expense.title}');
      return true;  // Success
    } else {
      print('DatabaseHelper: Duplicate expense found, skipping: ${expense.title}');
      return false;  // Duplicate
    }
  }

  // Lines 78-89: Get all expenses
  Future<List<Expense>> getAllExpenses() async {
    final db = await instance.database;
    
    // Query all rows, sorted by date descending (newest first)
    final result = await db.query(
      'expenses',
      orderBy: 'date DESC',
    );

    // Convert each map to Expense object
    return result.map((map) => Expense.fromMap(map)).toList();
  }

  // Lines 91-100: Update expense
  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    
    // Update row where id matches
    return await db.update(
      'expenses',
      expense.toMap(),           // New values
      where: 'id = ?',          // Match condition
      whereArgs: [expense.id],  // ID to match
    );
  }

  // Lines 102-110: Delete expense
  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    
    // Delete row where id matches
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

**Key Concepts**:

1. **Singleton Pattern**:
   - Only one database instance throughout app
   - Prevents multiple connections
   - Lazy initialization (created on first use)

2. **Duplicate Detection**:
   - Checks: title + amount + date
   - Same notification → Same values
   - Returns `false` if duplicate found

3. **Why composite key for duplicates?**
   - Title alone: User might buy from same merchant twice
   - Amount alone: Different merchants, same price
   - Date alone: Multiple transactions same time
   - **All three**: Very likely same transaction

4. **CRUD Operations**:
   - **C**reate: `insertExpense()`
   - **R**ead: `getAllExpenses()`
   - **U**pdate: `updateExpense()`
   - **D**elete: `deleteExpense()`

---

### 3.3 `category_model.dart`
**Location**: `/lib/models/category_model.dart`

```dart
// Lines 1-13: Category class
class Category {
  final String id;          // Unique identifier (e.g., "food")
  final String name;        // Display name (e.g., "Food & Dining")
  final String icon;        // Emoji icon (e.g., "🍔")
  final String color;       // Hex color (e.g., "#F59E0B")
  final bool isDefault;     // Built-in category?

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
  });

  // Lines 15-22: Convert to Map (for future database storage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'isDefault': isDefault ? 1 : 0,  // SQLite doesn't have boolean
    };
  }

  // Lines 24-32: Convert from Map
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      color: map['color'],
      isDefault: map['isDefault'] == 1,  // int → bool
    );
  }
}

// Lines 34-92: Default categories
class DefaultCategories {
  static final List<Category> categories = [
    Category(
      id: 'food',
      name: 'Food & Dining',
      icon: '🍔',
      color: '#F59E0B',  // Amber
      isDefault: true,
    ),
    Category(
      id: 'transport',
      name: 'Transport',
      icon: '🚗',
      color: '#3B82F6',  // Blue
      isDefault: true,
    ),
    // ... 8 more categories (shopping, healthcare, entertainment, etc.)
    Category(
      id: 'other',
      name: 'Other',
      icon: '✨',
      color: '#64748B',  // Gray
      isDefault: true,
    ),
  ];

  // Lines 94-180: Auto-categorization logic
  static String getCategoryForMerchant(String merchant) {
    final lowerMerchant = merchant.toLowerCase();  // Case-insensitive matching
    
    // Food & Dining detection
    if (lowerMerchant.contains('zomato') ||
        lowerMerchant.contains('swiggy') ||
        lowerMerchant.contains('dominos') ||
        lowerMerchant.contains('mcdonald') ||
        lowerMerchant.contains('kfc') ||
        lowerMerchant.contains('pizza') ||
        lowerMerchant.contains('restaurant') ||
        lowerMerchant.contains('cafe') ||
        lowerMerchant.contains('food')) {
      return 'food';
    }
    
    // Transport detection
    if (lowerMerchant.contains('uber') ||
        lowerMerchant.contains('ola') ||
        lowerMerchant.contains('rapido') ||
        lowerMerchant.contains('metro') ||
        lowerMerchant.contains('petrol') ||
        lowerMerchant.contains('fuel') ||
        lowerMerchant.contains('parking')) {
      return 'transport';
    }
    
    // Shopping detection
    if (lowerMerchant.contains('amazon') ||
        lowerMerchant.contains('flipkart') ||
        lowerMerchant.contains('myntra') ||
        lowerMerchant.contains('ajio') ||
        lowerMerchant.contains('meesho') ||
        lowerMerchant.contains('shop')) {
      return 'shopping';
    }
    
    // Entertainment detection
    if (lowerMerchant.contains('netflix') ||
        lowerMerchant.contains('prime') ||
        lowerMerchant.contains('hotstar') ||
        lowerMerchant.contains('spotify') ||
        lowerMerchant.contains('movie') ||
        lowerMerchant.contains('game')) {
      return 'entertainment';
    }
    
    // Bills detection
    if (lowerMerchant.contains('electricity') ||
        lowerMerchant.contains('water') ||
        lowerMerchant.contains('internet') ||
        lowerMerchant.contains('mobile') ||
        lowerMerchant.contains('recharge') ||
        lowerMerchant.contains('bill')) {
      return 'bills';
    }
    
    return 'other';  // Default category
  }
}
```

**Key Concepts**:

1. **Why keyword-based categorization?**
   - Simple and fast
   - No training data needed
   - 80% accuracy with minimal code
   - Easy to add new rules

2. **Color format**:
   - Hex string (e.g., "#F59E0B")
   - Converted to Color in UI: `Color(int.parse('0xFF' + color.substring(1)))`

3. **Emoji icons**:
   - Universal (cross-platform)
   - No asset files needed
   - Colorful and expressive

4. **Future improvements**:
   - User-defined categories
   - Machine learning classification
   - Smart learning from user edits

---

I'll continue with the remaining files in the next section. Let me create the complete document.
