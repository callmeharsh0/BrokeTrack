// Test file to verify account keyword filtering logic
void main() {
  print("🧪 Testing Account Keyword Filtering Logic\\n");
  print("=" * 60);

  // Test messages
  final testMessages = [
    // Should pass (contains account keywords)
    "Dear UPI user A/C X5929 debited by 125.0 trf to Tejas",
    "ICICI Bank Acct XX924 debited for Rs 4000.00",
    "Your account has been credited with Rs 500",
    "AC 123456789 debited by INR 1000",
    "a/c ending 1234 credited",
    "Transaction from a.c. 5678",

    // Should fail (no account keywords)
    "Your OTP is 123456",
    "Welcome to our service",
    "Your subscription expires tomorrow",
    "Payment reminder for your loan",
    "Congratulations! You won a prize",
  ];

  int passCount = 0;
  int failCount = 0;

  for (var message in testMessages) {
    final result = isAccountRelatedMessage(message);
    final emoji = result ? "✅" : "❌";

    if (result)
      passCount++;
    else
      failCount++;

    print("$emoji $result | $message");
  }

  print("\\n" + "=" * 60);
  print("📊 Results:");
  print("   ✅ Passed (contains account keywords): $passCount");
  print("   ❌ Failed (no account keywords): $failCount");
  print("=" * 60);
}

/// Checks if the message contains account-related keywords
/// Returns true if message contains: ac, A/c, a/c, account, acct, a.c, or their variations
bool isAccountRelatedMessage(String message) {
  final lowerCaseMessage = message.toLowerCase();

  // List of account-related patterns
  final accountKeywords = [
    'a/c', // Common abbreviation
    'ac ', // Account with space after
    ' ac', // Account with space before
    'a.c', // With dots
    'acct', // Account abbreviation
    'account', // Full word
  ];

  // Check if message contains any account-related keyword
  for (final keyword in accountKeywords) {
    if (lowerCaseMessage.contains(keyword)) {
      return true;
    }
  }

  return false;
}
