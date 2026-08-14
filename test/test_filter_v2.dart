// Updated comprehensive test for account keyword filtering
void main() {
  print("\\n🧪 ============================================");
  print("   COMPREHENSIVE ACCOUNT FILTER TEST v2");
  print("   (Updated with regex word boundaries)");
  print("============================================\\n");

  // Simulate the actual messages that would come from notifications
  final realWorldMessages = {
    // Transaction messages (should be processed)
    "✅ SHOULD PROCESS": [
      "Dear UPI user A/C X5929 debited by 125.0 trf to Tejas Hemant Susladkar",
      "ICICI Bank Acct XX924 debited for Rs 4000.00; Prajakta Rajend credited on 26oct25",
      "Your account has been credited with Rs 500.00 from Swiggy",
      "AC 123456789 debited by INR 1000 for Amazon purchase",
      "SBI: a/c ending 1234 credited Rs 2500 on 25-Nov-24",
      "Transaction from a.c. 5678 - Rs 350 debited",
      "HDFC Bank: Acct XX1234 credited INR 10000.00",
      "Bank of India: Your A/C has been debited Rs 75 for UPI",
    ],

    // Non-transaction messages (should be filtered)
    "❌ SHOULD FILTER": [
      "Your OTP is 123456. Valid for 5 minutes.",
      "Welcome to our premium service! Start your journey today.",
      "Your subscription expires in 3 days. Renew now!",
      "Payment reminder: Your EMI is due on 30th Nov",
      "Congratulations! You have won Rs 10000. Claim now!",
      "Netflix: Your plan has been activated", // Edge case: "activated" should not match
      "WhatsApp verification code: 456-789",
      "Amazon: Your order is out for delivery",
      "Practice makes perfect!", // Another edge case
      "Contact us for support", // Edge case: "contact" should not match
    ],
  };

  int totalPassed = 0;
  int totalFailed = 0;
  int correctlyProcessed = 0;
  int correctlyFiltered = 0;

  for (var category in realWorldMessages.entries) {
    print("\\n📋 Category: ${category.key}");
    print("-" * 60);

    final shouldProcess = category.key.contains("PROCESS");

    for (var message in category.value) {
      final result = isAccountRelatedMessage(message);
      final isCorrect =
          (shouldProcess && result) || (!shouldProcess && !result);

      String status;
      if (isCorrect) {
        if (shouldProcess) {
          status = "✅ PASS (Correctly passed to ML)";
          correctlyProcessed++;
        } else {
          status = "✅ PASS (Correctly filtered out)";
          correctlyFiltered++;
        }
        totalPassed++;
      } else {
        if (shouldProcess) {
          status = "❌ FAIL (Should process but filtered!)";
        } else {
          status = "❌ FAIL (Should filter but passed!)";
        }
        totalFailed++;
      }

      print("$status");
      print(
        "   Message: ${message.length > 50 ? message.substring(0, 50) + '...' : message}",
      );
    }
  }

  print("\\n" + "=" * 60);
  print("📊 FINAL RESULTS:");
  print("=" * 60);
  print("✅ Total Passed: $totalPassed");
  print("   - Correctly processed: $correctlyProcessed");
  print("   - Correctly filtered: $correctlyFiltered");
  print("❌ Total Failed: $totalFailed");
  print("");

  final accuracy = (totalPassed / (totalPassed + totalFailed) * 100);
  print("🎯 Accuracy: ${accuracy.toStringAsFixed(1)}%");

  if (totalFailed == 0) {
    print("🎉 ALL TESTS PASSED! Filtering logic works perfectly!");
  } else {
    print("⚠️  Some tests failed. Review the logic above.");
  }
  print("=" * 60 + "\\n");
}

/// Checks if the message contains account-related keywords
/// Returns true if message contains: ac, A/c, a/c, account, acct, a.c, or their variations
bool isAccountRelatedMessage(String message) {
  final lowerCaseMessage = message.toLowerCase();

  // Use regex patterns with word boundaries to avoid false matches
  // like "activated" or "practice" matching "ac"
  final accountPatterns = [
    RegExp(r'\ba/c\b'), // a/c as a standalone term
    RegExp(r'\ba\.c\b'), // a.c as a standalone term
    RegExp(r'\bac\s'), // ac followed by space
    RegExp(r'\sac\b'), // ac preceded by space
    RegExp(r'\bacct\b'), // acct as whole word
    RegExp(r'\baccount\b'), // account as whole word
  ];

  // Check if message matches any account-related pattern
  for (final pattern in accountPatterns) {
    if (pattern.hasMatch(lowerCaseMessage)) {
      return true;
    }
  }

  return false;
}
