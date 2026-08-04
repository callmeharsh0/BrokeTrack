// Test script to debug ML model predictions
import 'package:flutter/material.dart';
import 'ml_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("\n" + "=" * 70);
  print("🧪 ML MODEL DIAGNOSTIC TEST");
  print("=" * 70 + "\n");

  final mlService = MlService.instance;

  // Load model
  try {
    await mlService.loadModel();
  } catch (e) {
    print("❌ FATAL: Failed to load model: $e");
    return;
  }

  // Test SMS messages
  final testMessages = [
    "SMS HDFC : Credit Alert! Rs.1.00 credited to HDFC Bank A/c XX4862 on 23-11-25 from VPA prathamehta7@okicici (UPI 569377662984)",
    "Credit Alert! Rs.1.00 credited to HDFC Bank A/c XX4862 on 23-11-25 from VPA prathamehta7@okicici (UPI 569377662984)",
    "You paid Rs.250.00 to Zomato using Google Pay. UPI Ref: 123456789",
    "Your a/c XX1234 debited by Rs.500.00 on 26-Oct-25 for transaction at SWIGGY. -HDFC Bank",
    "Rs 150 debited from Paytm for payment to Amazon on 26-10-2025.",
    "Rs.1000.00 credited to your a/c XX5678 on 26-Oct-25. -ICICI Bank",
    "INR 75.50 paid to Uber via PhonePe",
  ];

  for (int i = 0; i < testMessages.length; i++) {
    print("\n" + "━" * 70);
    print("TEST ${i + 1}/${testMessages.length}");
    print("━" * 70);

    final result = mlService.predict(testMessages[i]);

    print("\n✨ FINAL RESULT:");
    print("   Merchant: '${result.merchant}'");
    print("   Amount: '${result.amount}'");
    print("   Bank: '${result.bankName}'");
    print("   Used Fallback: ${result.usedFallback}");
    print("━" * 70 + "\n");

    // Wait a bit between tests for readability
    await Future.delayed(Duration(milliseconds: 500));
  }

  print("\n" + "=" * 70);
  print("🏁 DIAGNOSTIC TEST COMPLETE");
  print("=" * 70 + "\n");

  mlService.dispose();
}
