import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'database_helper.dart';
import 'expense_model.dart';
import 'ml_service.dart';
import 'utils/theme.dart';
import 'utils/haptic_helper.dart';
import 'models/category_model.dart';
import 'screens/settings_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notitrack',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode
          .light, // Can be changed to ThemeMode.dark or ThemeMode.system
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final MlService mlService = MlService.instance;

  // Custom Native Plugin Channels
  static const platform = MethodChannel('notification_plugin/methods');
  static const eventChannel = EventChannel('notification_plugin/events');

  bool _isLoading = true;
  bool _isListenerEnabled = false;
  bool _testMode = false; // SET TO TRUE for testing
  int _notificationCount = 0;
  List<Expense> _expenses = [];

  // Duplicate notification prevention
  final Set<String> _processedNotificationHashes = {};
  static const int _maxHashCacheSize = 100;

  // Bottom Navigation
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  // Search & Filters
  String _searchQuery = '';
  String _selectedCategory = 'all';

  // Time Filter State
  String _selectedTimeFilter = 'all'; // all, currentMonth, lastMonth, custom
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  final List<String> _targetApps = [
    'com.google.android.apps.nbu.paisa.user', // GPay
    'net.one97.paytm', // PayTM
    'com.phonepe.app', // PhonePe
    'com.google.android.gm', // Gmail
    'com.android.messaging', // Default SMS
    'com.google.android.apps.messaging', // Google Messages
    'com.samsung.android.messaging', // Samsung Messages
    'zopsoft.com.zerofall', // ZeroFall
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Helper methods for calculations
  double get currentMonthIncome {
    final now = DateTime.now();
    return _expenses
        .where(
          (e) =>
              e.type == 'credit' &&
              e.date.year == now.year &&
              e.date.month == now.month,
        )
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get currentMonthExpenses {
    final now = DateTime.now();
    return _expenses
        .where(
          (e) =>
              e.type == 'debit' &&
              e.date.year == now.year &&
              e.date.month == now.month,
        )
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get currentMonthCashFlow {
    return currentMonthIncome - currentMonthExpenses;
  }

  List<Expense> get filteredExpenses {
    // 1. Filter by Time
    List<Expense> timeFiltered = _filterByTime(_expenses);

    // 2. Filter by Search & Category
    return timeFiltered.where((expense) {
      final matchesSearch =
          expense.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          expense.amount.toString().contains(_searchQuery);
      final matchesCategory =
          _selectedCategory == 'all' || expense.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<Expense> _filterByTime(List<Expense> expenses) {
    final now = DateTime.now();

    switch (_selectedTimeFilter) {
      case 'currentMonth':
        return expenses
            .where((e) => e.date.year == now.year && e.date.month == now.month)
            .toList();

      case 'lastMonth':
        final lastMonth = DateTime(now.year, now.month - 1);
        return expenses
            .where(
              (e) =>
                  e.date.year == lastMonth.year &&
                  e.date.month == lastMonth.month,
            )
            .toList();

      case 'custom':
        if (_customStartDate != null && _customEndDate != null) {
          // Include the end date fully (up to 23:59:59)
          final end = DateTime(
            _customEndDate!.year,
            _customEndDate!.month,
            _customEndDate!.day,
            23,
            59,
            59,
          );
          return expenses
              .where(
                (e) =>
                    e.date.isAfter(
                      _customStartDate!.subtract(const Duration(seconds: 1)),
                    ) &&
                    e.date.isBefore(end),
              )
              .toList();
        }
        return expenses;

      default: // 'all'
        return expenses;
    }
  }

  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedTimeFilter = 'custom'; // Ensure custom is selected
      });
    } else {
      // If cancelled and no range set, revert to 'all' if currently on custom
      if (_selectedTimeFilter == 'custom' && _customStartDate == null) {
        setState(() {
          _selectedTimeFilter = 'all';
        });
      }
    }
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isLoading = true;
    });
    try {
      print("🚀 === APP INITIALIZATION START ===");

      // 1. Load ML model
      print("📦 Loading ML model...");
      await mlService.loadModel();
      print("✅ ML model loaded");

      if (Platform.isAndroid) {
        print("🤖 Running on Android");
        // 2. Check notification permission
        bool isEnabled = await _checkNotificationPermission();
        print("🔔 Notification permission granted: $isEnabled");

        setState(() {
          _isListenerEnabled = isEnabled;
        });

        if (isEnabled) {
          // 3. Start listening
          _startNotificationListener();

          // 4. Process pending notifications from database
          print("📥 === CHECKING FOR PENDING NOTIFICATIONS ===");
          await _processPendingNotifications();
          print("✅ Pending notifications processed");
        } else {
          print("⚠️ Notification permission NOT granted");
        }
      } else {
        print("🍎 Running on iOS - using clipboard method");
      }

      // 5. Load expenses
      print("💾 Loading expenses from database...");
      await _refreshExpensesFromDb();
      print("✅ Loaded ${_expenses.length} expenses");

      print("🚀 === APP INITIALIZATION COMPLETE ===\n");
    } catch (e) {
      print("❌ ERROR on startup: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Custom Native Plugin Methods ---

  Future<bool> _checkNotificationPermission() async {
    try {
      final bool result = await platform.invokeMethod('isPermissionGranted');
      return result;
    } on PlatformException catch (e) {
      print("Error checking permission: ${e.message}");
      return false;
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      print("🔔 Opening notification permission settings...");
      await platform.invokeMethod('requestPermission');

      // Wait a bit for user to return from settings
      await Future.delayed(const Duration(seconds: 1));

      // Check permission again
      bool isEnabled = await _checkNotificationPermission();
      print("🔔 Permission status: $isEnabled");

      setState(() {
        _isListenerEnabled = isEnabled;
      });

      if (isEnabled) {
        _startNotificationListener();
      }
    } on PlatformException catch (e) {
      print("Error requesting permission: ${e.message}");
    }
  }

  void _startNotificationListener() {
    print("🎧 ========================================");
    print("🎧 STARTING NOTIFICATION LISTENER");
    if (_testMode) {
      print("🧪 TEST MODE ENABLED - Will process ALL notifications!");
    } else {
      print("🎧 Listening for packages: $_targetApps");
    }
    print("🎧 ========================================\n");

    eventChannel.receiveBroadcastStream().listen(
      (dynamic event) async {
        // Mark that we received a notification
        if (mounted) {
          setState(() {
            _notificationCount++;
          });
        }

        // Parse the event
        Map<String, dynamic> data = Map<String, dynamic>.from(event);
        String? packageName = data['packageName'];
        String? title = data['title'];
        String? content = data['content'];

        // Log everything
        print("\n==========================================");
        print(
          "📱 NOTIFICATION #$_notificationCount RECEIVED AT ${DateTime.now()}",
        );
        print("📦 Package: $packageName");
        print("📌 Title: $title");
        print("📝 Content: $content");
        print("🎯 Is Target App: ${_targetApps.contains(packageName)}");
        if (_testMode) {
          print("🧪 TEST MODE: Will process anyway!");
        }
        print("==========================================");

        if (packageName == null || (content == null && title == null)) {
          print("❌ SKIPPED: No package or content\n");
          return;
        }

        // Create notification hash to detect duplicates
        final notificationHash = '${title ?? ''}_${content ?? ''}_$packageName'
            .hashCode
            .toString();

        // Check if we've already processed this notification
        if (_processedNotificationHashes.contains(notificationHash)) {
          print("⚠️ DUPLICATE NOTIFICATION DETECTED - SKIPPING");
          print("   Hash: $notificationHash");
          print("==========================================");
          return;
        }

        // Add to processed set
        _processedNotificationHashes.add(notificationHash);

        // Keep cache size limited (remove oldest if needed)
        if (_processedNotificationHashes.length > _maxHashCacheSize) {
          final firstHash = _processedNotificationHashes.first;
          _processedNotificationHashes.remove(firstHash);
        }

        print("✅ New notification hash: $notificationHash");

        // In test mode, process ALL. Otherwise, only target apps
        if (_testMode || _targetApps.contains(packageName)) {
          print(
            "✅ ✅ ✅ ${_testMode ? 'TEST MODE' : 'TARGET APP MATCHED'}! ✅ ✅ ✅",
          );
          print("--- PROCESSING NOTIFICATION ---");

          // Construct full text
          // If title is a generic app name or looks like a sender ID (which we strip anyway),
          // we might not want to prepend it if it confuses the model.
          // However, for non-SMS apps (like GPay), the title might be "Payment to X".
          // Strategy:
          // 1. If title is generic (Messages, SMS), ignore it.
          // 2. If title is effectively the same as the start of content, ignore it.
          // 3. Otherwise, prepend it.

          String fullText = content ?? '';
          final titleLower = (title ?? '').toLowerCase();
          final genericTitles = ['messages', 'sms', 'message', 'notification'];

          bool shouldPrependTitle = true;

          if (title == null || title.isEmpty) {
            shouldPrependTitle = false;
          } else if (genericTitles.contains(titleLower)) {
            shouldPrependTitle = false;
          } else if ((content ?? '').startsWith(title)) {
            shouldPrependTitle = false;
          } else if (RegExp(r'^[A-Z]{2}-[A-Z0-9]{6}').hasMatch(title)) {
            // Title looks like a sender ID (e.g. VM-HDFCBK) -> Ignore it
            shouldPrependTitle = false;
          }

          if (shouldPrependTitle) {
            fullText = "$title $content";
          }

          print("📝 Full text: '$fullText'\n");

          Expense? newExpense = await _processSmsText(fullText, DateTime.now());

          if (newExpense != null) {
            print("💰 💰 💰 AI MODEL SUCCESS! 💰 💰 💰");
            print("   Merchant: ${newExpense.title}");
            print("   Amount: ₹${newExpense.amount}");
            print("   Bank: ${newExpense.bankName}");
            print("   Type: ${newExpense.type}");

            bool inserted = await dbHelper.insertExpense(newExpense);

            if (inserted) {
              print("✅ ✅ ✅ INSERTED TO DATABASE! ✅ ✅ ✅");

              // CRITICAL FIX: Clear this notification from pending database
              // to prevent duplicate insertion when app restarts
              try {
                await platform.invokeMethod('clearPendingNotifications');
                print(
                  "🗑️ Cleared from pending notifications (prevent duplicate)",
                );
              } catch (e) {
                print("⚠️ Failed to clear pending: $e");
              }

              await _refreshExpensesFromDb();
            } else {
              print("⚠️ DUPLICATE - NOT INSERTED");
            }
          } else {
            print("❌ AI MODEL RETURNED NULL - No transaction detected\n");
          }
        } else {
          print("⏭️ SKIPPED: Not a target app\n");
        }
      },
      onError: (error) {
        print("❌ NOTIFICATION LISTENER ERROR: $error");
      },
    );

    print("🎧 ✅ Listener is ACTIVE\n");
  }

  // --- SMS Processing ---

  /// Checks if the message contains account-related keywords
  /// Returns true if message contains: ac, A/c, a/c, account, acct, a.c, AC, A/C, Account or their variations
  bool _isAccountRelatedMessage(String message) {
    // Use regex patterns with word boundaries to avoid false matches
    // like "activated" or "practice" matching "ac"
    // Made case-insensitive to catch A/C, AC, Account, etc.
    final accountPatterns = [
      RegExp(r'\ba/c\b', caseSensitive: false), // a/c or A/C as standalone
      RegExp(r'\ba\.c\b', caseSensitive: false), // a.c or A.C as standalone
      RegExp(r'\bac\s', caseSensitive: false), // ac or AC followed by space
      RegExp(r'\sac\b', caseSensitive: false), // ac or AC preceded by space
      RegExp(
        r'\baccount\b',
        caseSensitive: false,
      ), // account or Account as whole word
      RegExp(r'^ac\s', caseSensitive: false), // ac or AC at start of message
      RegExp(r'\sac$', caseSensitive: false), // ac or AC at end of message
    ];

    // Check if message matches any account-related pattern
    for (final pattern in accountPatterns) {
      if (pattern.hasMatch(message)) {
        return true;
      }
    }

    return false;
  }

  Future<Expense?> _processSmsText(String smsBody, DateTime smsDate) async {
    print("\n🧠 === PROCESSING SMS TEXT ===");
    print("📝 Input: '$smsBody'");

    // First check if message contains account-related keywords
    if (!_isAccountRelatedMessage(smsBody)) {
      print(
        "⏭️ SKIPPED: Message does not contain account-related keywords (ac, A/c, account, etc.)",
      );
      print("🧠 === PROCESSING SKIPPED ===\n");
      return null;
    }

    print(
      "✅ Message contains account-related keywords - proceeding to ML model...",
    );

    // Use ML Model
    print("🤖 Calling ML model predict()...");
    PredictionResult result = mlService.predict(smsBody);

    print("🎯 ML Model Results:");
    print("   Merchant: '${result.merchant}'");
    print("   Amount: '${result.amount}'");
    print("   Bank: '${result.bankName}'");

    String lowerCaseSms = smsBody.toLowerCase();

    if (result.merchant.isNotEmpty && result.amount.isNotEmpty) {
      print("✅ Both merchant and amount found - proceeding...");

      // Determine debit/credit
      String transactionType = 'debit';
      if (lowerCaseSms.contains('credited') ||
          lowerCaseSms.contains('received') ||
          lowerCaseSms.contains('added')) {
        transactionType = 'credit';
      }
      print("💳 Transaction type: $transactionType");

      // Clean and parse amount
      final cleanAmount = result.amount.replaceAll(RegExp(r'[^0-9\.]'), '');
      print("🧹 Cleaned amount: '$cleanAmount' (from '${result.amount}')");

      final double? parsedAmount = double.tryParse(cleanAmount);

      if (parsedAmount == null) {
        print("❌ Failed to parse amount\n");
        return null;
      }

      print("✅ Creating expense object: ₹$parsedAmount\n");

      // Auto-categorize based on merchant name
      final category = DefaultCategories.getCategoryForMerchant(
        result.merchant,
      );
      print("📂 Auto-categorized as: $category");

      return Expense(
        title: result.merchant,
        amount: parsedAmount,
        date: smsDate,
        category: category,
        type: transactionType,
        bankName: result.bankName.isEmpty ? "Unknown" : result.bankName,
      );
    } else {
      print("❌ Missing required fields:");
      if (result.merchant.isEmpty) print("   - Merchant is empty");
      if (result.amount.isEmpty) print("   - Amount is empty");
      print("🧠 === PROCESSING FAILED ===\n");
    }

    return null;
  }

  // iOS clipboard paste
  Future<void> _pasteAndProcessSms() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);

    if (data == null || data.text == null || data.text!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your clipboard is empty.')),
        );
      }
      return;
    }

    Expense? newExpense = await _processSmsText(data.text!, DateTime.now());

    if (newExpense == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find a transaction in the pasted text.'),
          ),
        );
      }
      return;
    }

    _showExpenseDialog(expenseToEdit: newExpense);
  }

  // Process pending notifications from database
  Future<void> _processPendingNotifications() async {
    try {
      print("🔍 Fetching pending notifications from database...");

      // Get all pending notifications
      final List<dynamic> pendingNotifications = await platform.invokeMethod(
        'getPendingNotifications',
      );

      print("📊 Found ${pendingNotifications.length} pending notifications");

      if (pendingNotifications.isEmpty) {
        print("✅ No pending notifications to process");
        return;
      }

      int processedCount = 0;
      int insertedCount = 0;

      // Process each pending notification
      for (var notification in pendingNotifications) {
        String? packageName = notification['packageName'];
        String? title = notification['title'] ?? '';
        String? content = notification['content'] ?? '';
        String? timestamp = notification['timestamp'];

        print("\n==========================================");
        print("📥 PROCESSING PENDING NOTIFICATION #${processedCount + 1}");
        print("📦 Package: $packageName");
        print("📌 Title: $title");
        print("📝 Content: $content");
        print("🕐 Timestamp: $timestamp");
        print("🎯 Is Target App: ${_targetApps.contains(packageName)}");
        print("==========================================");

        // Check if it's a target app (or test mode)
        if (_testMode || _targetApps.contains(packageName)) {
          // Use same logic as real-time notifications
          String fullText = content ?? '';
          final titleLower = (title ?? '').toLowerCase();
          final genericTitles = ['messages', 'sms', 'message', 'notification'];

          bool shouldPrependTitle = true;

          if (title == null || title.isEmpty) {
            shouldPrependTitle = false;
          } else if (genericTitles.contains(titleLower)) {
            shouldPrependTitle = false;
          } else if ((content ?? '').startsWith(title)) {
            shouldPrependTitle = false;
          } else if (RegExp(r'^[A-Z]{2}-[A-Z0-9]{6}').hasMatch(title)) {
            shouldPrependTitle = false;
          }

          if (shouldPrependTitle) {
            fullText = "$title $content";
          }

          print("📝 Full text: '$fullText'");

          // Parse timestamp
          DateTime notificationDate;
          if (timestamp != null) {
            try {
              notificationDate = DateTime.fromMillisecondsSinceEpoch(
                int.parse(timestamp),
              );
            } catch (e) {
              notificationDate = DateTime.now();
            }
          } else {
            notificationDate = DateTime.now();
          }

          // Process through ML model
          Expense? newExpense = await _processSmsText(
            fullText,
            notificationDate,
          );

          if (newExpense != null) {
            print("💰 AI MODEL SUCCESS! - ${newExpense.title}");
            bool inserted = await dbHelper.insertExpense(newExpense);

            if (inserted) {
              print("✅ INSERTED TO DATABASE!");
              insertedCount++;
            } else {
              print("⚠️ DUPLICATE - NOT INSERTED");
            }
          } else {
            print("❌ AI MODEL RETURNED NULL - No transaction detected");
          }
        } else {
          print("⏭️ SKIPPED: Not a target app");
        }

        processedCount++;
      }

      print("\n========================================");
      print("🎉 PENDING NOTIFICATION PROCESSING COMPLETE");
      print("   Processed: $processedCount");
      print("   Inserted: $insertedCount");
      print("========================================\n");

      // Clear all pending notifications from database
      await platform.invokeMethod('clearPendingNotifications');
      print("🗑️ Cleared pending notifications from database");

      // Refresh expense list
      await _refreshExpensesFromDb();
    } on PlatformException catch (e) {
      print("❌ Error processing pending notifications: ${e.message}");
    } catch (e) {
      print("❌ Unexpected error processing pending notifications: $e");
    }
  }

  // --- Database ---

  Future<void> _refreshExpensesFromDb() async {
    final data = await dbHelper.getAllExpenses();
    if (mounted) {
      setState(() {
        _expenses = data;
      });
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Loading...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (Platform.isAndroid && !_isListenerEnabled) {
      return Scaffold(body: _buildPermissionScreen());
    }

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [_buildDashboard(), _buildTransactions()],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(0),
            topRight: Radius.circular(0),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              HapticHelper.selection();
              setState(() {
                _selectedIndex = index;
              });
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF6366F1),
            unselectedItemColor: Colors.grey,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: 'Transactions',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                HapticHelper.medium();
                _showExpenseDialog();
              },
              backgroundColor: AppTheme.primaryPurple,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  // Dashboard Tab
  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          // Title
          Text(
            'Dashboard',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 24),

          // Cash Flow Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Cash Flow',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${currentMonthCashFlow.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Income & Expense Row
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Income',
                  currentMonthIncome,
                  const Color(0xFF10B981),
                  Icons.arrow_upward,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Expenses',
                  currentMonthExpenses,
                  const Color(0xFFEF4444),
                  Icons.arrow_downward,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Quick Add Buttons Row
          Row(
            children: [
              // Quick Add Transaction Button
              Expanded(
                flex: Platform.isIOS ? 1 : 1,
                child: ElevatedButton(
                  onPressed: () => _showExpenseDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Quick Add',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // iOS Paste Button
              if (Platform.isIOS) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: _pasteAndProcessSms,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.paste, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Paste SMS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 32),

          // Recent Transactions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selectedIndex = 1);
                  _pageController.jumpToPage(1);
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_expenses.isEmpty)
            _buildEmptyState()
          else
            ..._expenses
                .take(5)
                .map((expense) => _buildTransactionTile(expense)),

          const SizedBox(height: 32),

          // Analytics & Settings
          Row(
            children: [
              Expanded(
                child: _buildActionCard('Analytics', Icons.bar_chart, () {}),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard('Settings', Icons.settings, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ).then((_) => _refreshExpensesFromDb());
                }),
              ),
            ],
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // Transactions Tab
  Widget _buildTransactions() {
    return Column(
      children: [
        const SizedBox(height: 40),
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transactions',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              // Removed "X transactions" text as requested
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search transactions...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Time Filters
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildTimeFilterChip('all', 'All Time'),
              _buildTimeFilterChip('currentMonth', 'Current Month'),
              _buildTimeFilterChip('lastMonth', 'Last Month'),
              _buildTimeFilterChip('custom', 'Custom'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Category Chips
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryChip('all', 'All'),
              _buildCategoryChip('food', 'Food & Dining'),
              _buildCategoryChip('transport', 'Transportation'),
              _buildCategoryChip('shopping', 'Shopping'),
              _buildCategoryChip('entertainment', 'Entertainment'),
              _buildCategoryChip('health', 'Health'),
              _buildCategoryChip('bills', 'Bills'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // List
        Expanded(
          child: filteredExpenses.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredExpenses.length,
                  itemBuilder: (context, index) {
                    return _buildTransactionTile(filteredExpenses[index]);
                  },
                ),
        ),
      ],
    );
  }

  // --- Helper Widgets ---

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Expense expense) {
    final bool isCredit = expense.type == 'credit';
    final Color color = isCredit
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final String prefix = isCredit ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(expense.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) async {
                HapticHelper.heavy();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Expense'),
                    content: const Text(
                      'Are you sure you want to delete this expense?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true && expense.id != null) {
                  HapticHelper.success();
                  await dbHelper.deleteExpense(expense.id!);
                  await _refreshExpensesFromDb();
                }
              },
              backgroundColor: const Color(0xFFFE4A49),
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(16),
              ),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _showExpenseDialog(expenseToEdit: expense),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCredit ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${expense.bankName} • ${DateFormat('MMM d, h:mm a').format(expense.date)}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$prefix₹${expense.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilterChip(String value, String label) {
    final isSelected = _selectedTimeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedTimeFilter = value;
              if (value == 'custom') {
                _showCustomDatePicker();
              }
            });
          }
        },
        selectedColor: const Color(0xFF6366F1),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label) {
    final bool isSelected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _selectedCategory = selected ? id : 'all';
          });
        },
        selectedColor: const Color(0xFF6366F1),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Transactions will appear here',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: const Color(0xFF6366F1)),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active,
                size: 64,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Enable Live Tracking',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'To automatically track expenses from GPay, PayTM, and other apps, please enable notification access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _requestNotificationPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Enable Permission',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExpenseDialog({Expense? expenseToEdit}) async {
    final titleController = TextEditingController(text: expenseToEdit?.title);
    final amountController = TextEditingController(
      text: expenseToEdit?.amount.toString(),
    );
    final bankController = TextEditingController(text: expenseToEdit?.bankName);
    String transactionType = expenseToEdit?.type ?? 'debit';

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                expenseToEdit == null ? 'Add Expense' : 'Edit Expense',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title / Merchant',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: bankController,
                      decoration: InputDecoration(
                        labelText: 'Bank / Source',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setDialogState(() => transactionType = 'debit'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: transactionType == 'debit'
                                    ? const Color(0xFFEF4444).withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: transactionType == 'debit'
                                      ? const Color(0xFFEF4444)
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Expense',
                                  style: TextStyle(
                                    color: transactionType == 'debit'
                                        ? const Color(0xFFEF4444)
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(
                              () => transactionType = 'credit',
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: transactionType == 'credit'
                                    ? const Color(0xFF10B981).withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: transactionType == 'credit'
                                      ? const Color(0xFF10B981)
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Income',
                                  style: TextStyle(
                                    color: transactionType == 'credit'
                                        ? const Color(0xFF10B981)
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save'),
                  onPressed: () async {
                    final String title = titleController.text;
                    final double? amount = double.tryParse(
                      amountController.text,
                    );

                    if (title.isNotEmpty && amount != null && amount > 0) {
                      HapticHelper.success();
                      final newExpense = Expense(
                        date: expenseToEdit?.date ?? DateTime.now(),
                        title: title,
                        amount: amount,
                        bankName: bankController.text.isEmpty
                            ? (expenseToEdit?.bankName ?? "Cash")
                            : bankController.text,
                        type: transactionType,
                        category: "Uncategorized",
                      );

                      await dbHelper.insertExpense(newExpense);
                      _refreshExpensesFromDb();
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
