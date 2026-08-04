/// Post-processing utilities for cleaning ML-extracted entities
/// Generalizes to handle various SMS formats from different banks
class EntityCleaner {
  // Comprehensive list of Indian banks
  static const List<String> KNOWN_BANKS = [
    'sbi',
    'hdfc',
    'icici',
    'axis',
    'kotak',
    'pnb',
    'bob',
    'canara',
    'union',
    'federal',
    'yes',
    'idbi',
    'paytm',
    'suvarnayug',
    'fino',
    'idfc',
    'rbl',
    'dbs',
    'hsbc',
    'standard chartered',
    'citi',
    'uco',
    'indian',
    'central',
    'syndicate',
    'allahabad',
    'corporation',
    'vijaya',
    'dena',
    'oriental',
    'andhra',
    'maharashtra',
    'karnataka',
  ];

  /// Clean amount: Remove currency symbols, transaction IDs, and junk
  /// Handles: "rs.1.00530666401342n" → "1.00"
  static String cleanAmount(String rawAmount) {
    if (rawAmount.isEmpty) return '';

    // Step 1: Remove currency prefixes (case insensitive)
    var cleaned = rawAmount.replaceAll(
      RegExp(r'\b(rs\.?|inr\.?|₹|rupees?)\s*', caseSensitive: false),
      '',
    );

    // Step 2: Extract just the amount (first valid number)
    // Pattern: digits, optional dot, digits
    final amountMatch = RegExp(r'(\d+\.?\d{0,2})').firstMatch(cleaned);
    if (amountMatch == null) return '';

    var amount = amountMatch.group(1) ?? '';

    // Step 3: Remove trailing non-numeric characters
    amount = amount.replaceAll(RegExp(r'[^\d.]'), '');

    // Step 4: Validate and format
    try {
      final value = double.parse(amount);
      // Sanity check: Valid transaction amounts
      if (value >= 0.01 && value <= 10000000) {
        return value.toStringAsFixed(2);
      }
    } catch (e) {
      return '';
    }

    return '';
  }

  /// Clean merchant: Remove common suffixes, codes, and junk
  /// Handles:
  /// - "mumtajbegarn rah refno" → "mumtajbegarn rah"
  /// - "pramila sharad gholap-g055051" → "pramila sharad gholap"
  static String cleanMerchant(String rawMerchant) {
    if (rawMerchant.isEmpty || rawMerchant == 'NONE') return '';

    var cleaned = rawMerchant.toLowerCase().trim();

    // Pattern 1: Remove "refno" or "ref" suffixes
    cleaned = cleaned.replaceAll(RegExp(r'\s*(refno?)\s*$'), '');

    // Pattern 2: Remove date suffixes like "on 19oct25"
    cleaned = cleaned.replaceAll(RegExp(r'\s*on\s+\d{1,2}[a-z]{3}\d{2}$'), '');

    // Pattern 3: Remove UPI/transaction suffixes
    cleaned = cleaned.replaceAll(RegExp(r'\s*(upi|txn|trf)\s*$'), '');

    // Pattern 4: Remove alphanumeric codes (e.g., "-g055051")
    cleaned = cleaned.replaceAll(RegExp(r'-[a-z]\d+$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'-\d+$'), ''); // "-123456"

    // Pattern 5: Remove "to" suffix
    cleaned = cleaned.replaceAll(RegExp(r'\s+to\s*$'), '');

    // Pattern 6: Consolidate multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Validation: Must be at least 2 characters
    return cleaned.length >= 2 ? cleaned : '';
  }

  /// Clean bank: Extract bank name from junk (phone numbers, service codes)
  /// Handles:
  /// - "services18001234sbi" → "sbi"
  /// - "bank" → search original SMS for real bank name
  static String cleanBank(String rawBank, String originalSms) {
    if (rawBank.isEmpty) return '';

    var cleaned = rawBank.toLowerCase().trim();

    // Strategy 1: If contains a known bank, extract it
    for (var bank in KNOWN_BANKS) {
      if (cleaned.contains(bank)) {
        return bank;
      }
    }

    // Strategy 2: If it's too generic ("bank"), search original SMS
    if (cleaned == 'bank' || cleaned == 'banks') {
      final smsLower = originalSms.toLowerCase();
      for (var bank in KNOWN_BANKS) {
        if (smsLower.contains(bank)) {
          return bank;
        }
      }
      // Keep generic if can't find
      return cleaned;
    }

    // Strategy 3: If contains 4+ digits (likely phone/service code), search SMS
    final digitCount = RegExp(r'\d').allMatches(cleaned).length;
    if (digitCount >= 4) {
      final smsLower = originalSms.toLowerCase();
      for (var bank in KNOWN_BANKS) {
        if (smsLower.contains(bank)) {
          return bank;
        }
      }
      return ''; // Invalid if can't extract
    }

    // Return as-is if it seems valid (at least 3 chars, not too many digits)
    if (cleaned.length >= 3 && digitCount < 4) {
      return cleaned;
    }

    return '';
  }

  /// Extract UPI ID if merchant looks like one
  /// Keeps UPI IDs as-is: "harsh@okicici" stays "harsh@okicici"
  static bool isUpiId(String merchant) {
    return RegExp(r'[a-z0-9]+@[a-z]+', caseSensitive: false).hasMatch(merchant);
  }

  /// Clean all entities in one call
  static Map<String, String> cleanAll({
    required String amount,
    required String merchant,
    required String bank,
    required String originalSms,
  }) {
    // Clean amount first
    final cleanedAmount = cleanAmount(amount);

    // Clean merchant (preserve UPI IDs)
    var cleanedMerchant = merchant;
    if (!isUpiId(merchant)) {
      cleanedMerchant = cleanMerchant(merchant);
    } else {
      cleanedMerchant = merchant.toLowerCase().trim();
    }

    // Clean bank
    final cleanedBank = cleanBank(bank, originalSms);

    return {
      'amount': cleanedAmount,
      'merchant': cleanedMerchant,
      'bank': cleanedBank,
    };
  }
}
