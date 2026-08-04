import 'package:flutter_test/flutter_test.dart';
import 'package:application_flutter/ml_service.dart';

void main() {
  group('MlService Fallback Tests', () {
    late MlService mlService;

    setUp(() {
      mlService = MlService.instance;
      // We intentionally do NOT load the model here to force fallback
    });

    test('Fallback extraction for simple payment', () {
      final sms =
          "You paid Rs.250.00 to Zomato using Google Pay. UPI Ref: 123456789";
      final result = mlService.predict(sms);

      expect(result.usedFallback, isTrue);
      expect(result.amount, equals('250')); // .00 is stripped
      // Fallback might capture 'Zomato' or similar depending on logic
      // Based on logic: "paid ... to Zomato"
      expect(result.merchant.toLowerCase(), contains('zomato'));
    });

    test('Fallback extraction for debit message', () {
      final sms =
          "Your a/c XX1234 debited by Rs.500.00 on 26-Oct-25 for transaction at SWIGGY. -HDFC Bank";
      final result = mlService.predict(sms);

      expect(result.usedFallback, isTrue);
      expect(result.amount, equals('500')); // .00 is stripped
      expect(result.bankName.toLowerCase(), contains('hdfc'));
      expect(result.merchant.toLowerCase(), contains('swiggy'));
    });

    test('Fallback extraction for credit message', () {
      final sms =
          "Rs.1000.00 credited to your a/c XX5678 on 26-Oct-25. -ICICI Bank";
      final result = mlService.predict(sms);

      expect(result.usedFallback, isTrue);
      expect(result.amount, equals('1000')); // .00 is stripped
      expect(result.bankName.toLowerCase(), contains('icici'));
    });

    test('Fallback extraction for simple sent message', () {
      final sms = "Sent Rs.125.00 From HDFC Bank To MC DONALDS";
      final result = mlService.predict(sms);

      expect(result.usedFallback, isTrue);
      expect(result.amount, equals('125')); // .00 is stripped
      expect(result.merchant.toLowerCase(), contains('mc donalds'));
      expect(result.bankName.toLowerCase(), contains('hdfc'));
    });

    test('Fallback extraction for UPI payment', () {
      final sms = "INR 75.50 paid to Uber via PhonePe";
      final result = mlService.predict(sms);

      expect(result.usedFallback, isTrue);
      expect(result.amount, equals('75.50'));
      expect(result.merchant.toLowerCase(), contains('uber'));
    });
  });
}
