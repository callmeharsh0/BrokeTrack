// lib/services/ml_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/entity_cleaner.dart';

class PredictionResult {
  final String merchant;
  final String amount;
  final String bankName;
  final List<String> words;
  final List<String> tags;
  final bool usedFallback;

  PredictionResult({
    required this.merchant,
    required this.amount,
    required this.bankName,
    required this.words,
    required this.tags,
    this.usedFallback = false,
  });

  @override
  String toString() =>
      'Merchant: "$merchant", Amount: "$amount", Bank: "$bankName", usedFallback: $usedFallback';
}

class MlService {
  MlService._();
  static final MlService instance = MlService._();
  factory MlService() => instance;

  Interpreter? _interpreter;
  Map<String, int> _wordIndex = {};
  Map<int, String> _idx2tag = {};
  int _oovToken = 1;
  static const int _maxLen = 75;

  // A small built-in bank name list to help fallback detection.
  // You can expand this or load from an asset file if you want.
  static final Set<String> _commonBanks = {
    'hdfc',
    'sbi',
    'icici',
    'axis',
    'kotak',
    'pnb',
    'bob',
    'idbi',
    'canara',
    'union',
    'indian',
    'yes',
    'idfc',
    'paytm',
    'phonepe',
    'au',
    'bankofbaroda',
    'bank',
    'bankofindia',
  };

  // ----------------------------
  // Preprocessing helpers
  // ----------------------------
  String _cleanText(String text) {
    if (text.isEmpty) return "";
    text = text.toLowerCase();
    text = text.replaceAll("\n", " ").replaceAll("\r", " ");
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    return text.trim();
  }

  String _normalize(String token) {
    // Matches Python: preserve spaces for multi-word matching
    token = token.toLowerCase().trim();
    // Remove special chars but KEEP spaces (note the space in character class)
    token = token.replaceAll(RegExp(r'[^a-z0-9\\.\\*@ ]'), '');
    // Consolidate multiple spaces to single space
    token = token.replaceAll(RegExp(r'\s+'), ' ');
    return token.trim();
  }

  List<String> _tokenizeAndNormalize(String text) {
    final cleaned = _cleanText(text);
    if (cleaned.isEmpty) return [];
    final rawTokens = cleaned.split(' ');
    final normalized = rawTokens
        .map((t) => _normalize(t))
        .where((t) => t.isNotEmpty)
        .toList();
    return normalized;
  }

  // ----------------------------
  // Model & tokenizers load
  // ----------------------------
  Future<void> loadModel({
    String modelAsset = 'assets/sms_ner_csv_labels.tflite',
    String wordTokAsset = 'assets/word_tokenizer_csv.json',
    String tagTokAsset = 'assets/tag_tokenizer_csv.json',
  }) async {
    try {
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      print("🚀 Loading NER Model & Tokenizers...");
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

      // Load model
      _interpreter = await Interpreter.fromAsset(modelAsset);
      print("✓ TFLite model loaded");
      try {
        print("  Input shape: ${_interpreter!.getInputTensor(0).shape}");
        print("  Output shape: ${_interpreter!.getOutputTensor(0).shape}");
      } catch (_) {}

      // Load word tokenizer JSON
      var wordJson = await rootBundle.loadString(wordTokAsset);
      dynamic wordData = json.decode(wordJson);
      // handle if the Keras tokenizer JSON itself was stringified inside
      if (wordData is String) {
        wordData = json.decode(wordData);
      }
      if (wordData is Map && wordData.containsKey('config')) {
        final config = wordData['config'] as Map<String, dynamic>;
        var indexWordRaw = config['index_word'];
        Map<String, dynamic> indexWord;
        if (indexWordRaw is String) {
          indexWord = json.decode(indexWordRaw) as Map<String, dynamic>;
        } else {
          indexWord = Map<String, dynamic>.from(indexWordRaw ?? {});
        }

        _wordIndex = {};
        indexWord.forEach((idx, word) {
          _wordIndex[word.toString()] = int.parse(idx);
        });

        // determine oov token index if present
        final oov = config['oov_token'];
        if (oov != null && oov is String && _wordIndex.containsKey(oov)) {
          _oovToken = _wordIndex[oov]!;
        } else {
          _oovToken = 1; // fallback
        }
      } else {
        // fallback: try to interpret as { 'word_index': { ... } }
        if (wordData is Map && wordData.containsKey('word_index')) {
          Map<String, dynamic> wi = Map<String, dynamic>.from(
            wordData['word_index'],
          );
          _wordIndex = wi.map((k, v) => MapEntry(k, (v as num).toInt()));
          _oovToken = _wordIndex['<OOV>'] ?? 1;
        } else {
          print(
            "⚠️ Could not parse word tokenizer json structure. Word-index may be empty.",
          );
        }
      }

      print(
        "✓ Word tokenizer loaded (vocab: ${_wordIndex.length}, oov: $_oovToken)",
      );
      // DEBUG: Show first 10 words in vocabulary
      print(
        "  📝 Sample vocab (first 10): ${_wordIndex.keys.take(10).join(', ')}",
      );

      // Load tag tokenizer JSON (expected format: { "idx2tag": { "0": "PAD", "1": "O", ... } } )
      var tagJson = await rootBundle.loadString(tagTokAsset);
      final tagData = json.decode(tagJson) as Map<String, dynamic>;
      Map<String, dynamic> idx2tagRaw = {};
      if (tagData.containsKey('idx2tag')) {
        idx2tagRaw = Map<String, dynamic>.from(tagData['idx2tag']);
      } else if (tagData.containsKey('index_word')) {
        // older formats
        idx2tagRaw = Map<String, dynamic>.from(tagData['index_word']);
      } else if (tagData.containsKey('config')) {
        // maybe keras tokenizer format for tags - fallback
        final config = tagData['config'] as Map<String, dynamic>;
        var indexWordRaw = config['index_word'];
        if (indexWordRaw is String) {
          idx2tagRaw = json.decode(indexWordRaw) as Map<String, dynamic>;
        } else {
          idx2tagRaw = Map<String, dynamic>.from(indexWordRaw ?? {});
        }
      }

      _idx2tag = {};
      idx2tagRaw.forEach((k, v) {
        final idx = int.tryParse(k);
        if (idx != null) {
          _idx2tag[idx] = v.toString();
        }
      });

      print("✓ Tag tokenizer loaded (count: ${_idx2tag.length})");
      // DEBUG: Show complete tag mappings
      print("  📋 Complete tag mappings:");
      _idx2tag.forEach((idx, tag) {
        print("     Index $idx → $tag");
      });
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      print("✅ ML Service initialized successfully!");
      print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");
    } catch (e, st) {
      print("❌ Error loading model/tokenizers: $e");
      print(st);
      rethrow;
    }
  }

  // ----------------------------
  // Sequence helpers
  // ----------------------------
  List<int> _textsToSequences(List<String> words) {
    // Keras tokenizer splits words on special characters
    // e.g., "rs.1.00" becomes ["rs", ".", "1", ".", "00"]
    // We need to replicate this behavior
    final sequences = <int>[];

    for (final word in words) {
      // Split on any non-alphanumeric character while keeping the separators
      // This matches Keras's word split behavior
      final subTokens = word
          .split(RegExp(r'(\W+)')) // FIXED: Single backslash for \W
          .where((t) => t.isNotEmpty);

      for (final token in subTokens) {
        final idx = _wordIndex[token] ?? _oovToken;
        sequences.add(idx);
      }
    }

    return sequences;
  }

  List<int> _padSequence(List<int> seq, int maxLen) {
    final padded = List<int>.filled(maxLen, 0);
    final copyLen = seq.length < maxLen ? seq.length : maxLen;
    for (int i = 0; i < copyLen; i++) padded[i] = seq[i];
    return padded;
  }

  // Helper to check if an amount looks like a real transaction amount

  // ----------------------------
  // Amount / Merchant / Bank Parsers (fallback)
  // ----------------------------
  // returns first meaningful match or empty
  String _fallbackExtractAmount(String rawText) {
    final text = rawText.replaceAll(',', '');

    // Priority 1: Explicit currency symbols (Rs. 123, INR 123)
    // We use a stricter regex here to ensure we catch the currency symbol
    final currencyPattern = RegExp(
      r'(?:rs|inr)[\.\s]*([0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final currencyMatch = currencyPattern.firstMatch(text);
    if (currencyMatch != null) {
      return currencyMatch.group(1) ?? '';
    }

    // Priority 2: Look for numbers that are likely amounts (e.g. with decimals)
    // But avoid things that look like account numbers (XX1234) or years (2025)
    final numericPattern = RegExp(r'\b([0-9]+(?:\.[0-9]{1,2})?)\b');
    final matches = numericPattern.allMatches(text);

    for (final m in matches) {
      final val = m.group(1) ?? '';
      if (val.isEmpty) continue;

      // Skip if it looks like a year (2020-2030) and is an integer
      if (!val.contains('.') && val.startsWith('20') && val.length == 4) {
        final n = int.tryParse(val);
        if (n != null && n >= 2000 && n <= 2030) continue;
      }

      // Skip if preceded by 'XX' or 'x' (account masking)
      final start = m.start;
      if (start > 0) {
        final prefix = text.substring(0, start).trimRight();
        if (prefix.endsWith('X') ||
            prefix.endsWith('x') ||
            prefix.endsWith('/c') ||
            prefix.endsWith('no')) {
          continue;
        }
      }

      // Skip if it looks like an OTP (4-6 digits, integer)
      if (!val.contains('.') && (val.length == 4 || val.length == 6)) {
        // This is risky, but amounts usually have context.
        // If we didn't find "Rs", we are guessing.
        // Let's accept it if it has a decimal, otherwise be skeptical?
        // For now, let's assume if it passed the account check, it might be okay.
        // But 1234 in "XX1234" was the issue. The account check above should catch that.
      }

      // If we are here, it's a candidate.
      // If it has a decimal, it's a strong candidate.
      if (val.contains('.')) return val;

      // If it's an integer, we return it but keep looking if there's a better one?
      // The original logic returned the first match. Let's return this one for now.
      return val;
    }

    return '';
  }

  String _fallbackExtractBank(String rawText) {
    final words = _tokenizeAndNormalize(rawText);

    // Priority 1: Look for known bank names
    for (int i = 0; i < words.length; i++) {
      final w = words[i].replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (w.isEmpty) continue;

      if (_commonBanks.contains(w)) {
        // Found a known bank!
        // Return it, maybe with 'bank' if it follows
        if (i + 1 < words.length && words[i + 1].contains('bank')) {
          return '$w bank';
        }
        return w;
      }
    }

    // Priority 2: Look for 'bank' keyword or account patterns
    for (int i = 0; i < words.length; i++) {
      final w = words[i].replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (w.isEmpty) continue;

      if (w.contains('bank')) {
        // Return the word before it if it exists
        if (i > 0) {
          return '${words[i - 1]} bank';
        }
        return 'bank';
      }

      if (w.startsWith('acct') ||
          w.startsWith('ac') ||
          w.startsWith('a/c') ||
          w.startsWith('A/c') ||
          w.startsWith('AC') ||
          w.startsWith('A/C')) {
        // build a small snippet around it
        final start = i;
        final end = (i + 3 < words.length) ? i + 3 : words.length - 1;
        return words.sublist(start, end + 1).join(' ').trim();
      }
      // masked account patterns
      if (RegExp(r'xx\d{2,4}|x{2,}\d{2,4}|[*]{1,}\d{2,4}').hasMatch(words[i])) {
        return words[i];
      }
    }
    // look for phone-like tokens that might be bank helplines — but only return if clearly bank token found
    return '';
  }

  String _fallbackExtractMerchant(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return '';

    // ========================================
    // BANK-SPECIFIC PATTERNS (Most reliable)
    // ========================================

    // 1. ICICI Pattern: "; MERCHANT credited"
    // Example: "ICICI Bank Acct XX924 debited for Rs 4000.00; Prajakta Rajend credited"
    final iciciPattern = RegExp(
      r';\s*([^;]+?)\s+credited',
      caseSensitive: false,
    );
    final iciciMatch = iciciPattern.firstMatch(text);
    if (iciciMatch != null) {
      String merchant = iciciMatch.group(1)?.trim() ?? '';
      merchant = merchant.replaceAll(RegExp(r'\bon\s+\d'), '').trim();
      merchant = merchant.replaceAll(RegExp(r'UPI:.*'), '').trim();
      merchant = merchant.replaceAll(RegExp(r'\.\s*$'), '').trim();
      if (merchant.isNotEmpty && merchant.length > 2) return merchant;
    }

    // 2. SBI Pattern: "trf to MERCHANT" or "transfer from MERCHANT"
    // Example: "Dear UPI user A/C X5929 debited by 125.0 trf to Tejas Hemant Susladkar"
    final sbiPattern = RegExp(
      r'(?:trf to|transfer (?:from|to))\s+([A-Z\s\.]+?)(?:\s+Ref|$)',
      caseSensitive: false,
    );
    final sbiMatch = sbiPattern.firstMatch(text);
    if (sbiMatch != null) {
      String merchant = sbiMatch.group(1)?.trim() ?? '';
      if (merchant.isNotEmpty && merchant.length > 2) return merchant;
    }

    // 3. HDFC Pattern: "To MERCHANT" or "From ... To MERCHANT"
    // Example: "Sent Rs.125.00 From HDFC Bank To MC DONALDS"
    final hdfcPattern = RegExp(
      r'\bTo\s+([A-Z\s]+?)(?:\s+On\s+|\s+Ref\s+|$)',
      caseSensitive: false,
    );
    final hdfcMatch = hdfcPattern.firstMatch(text);
    if (hdfcMatch != null) {
      String merchant = hdfcMatch.group(1)?.trim() ?? '';
      if (merchant.isNotEmpty && merchant.length > 2) return merchant;
    }

    // 4. HDFC Credit Pattern: "from VPA MERCHANT"
    // Example: "credited from VPA harshofficial654-1@okaxis"
    final hdfcCreditPattern = RegExp(
      r'from VPA\s+([^\s]+)',
      caseSensitive: false,
    );
    final hdfcCreditMatch = hdfcCreditPattern.firstMatch(text);
    if (hdfcCreditMatch != null) {
      String merchant = hdfcCreditMatch.group(1)?.trim() ?? '';
      // Remove @domain part
      merchant = merchant.split('@')[0];
      if (merchant.isNotEmpty && merchant.length > 2) return merchant;
    }

    // 5. IPPB Pattern: "for UPI to MERCHANT" or "Debit ... for UPI to MERCHANT"
    // Example: "A/C X5499 Debit Rs.500.00 for UPI to harsh panduran"
    final ippbPattern = RegExp(
      r'for UPI to\s+([^o][^n]+?)(?:\s+on\s+|\s+Ref|$)',
      caseSensitive: false,
    );
    final ippbMatch = ippbPattern.firstMatch(text);
    if (ippbMatch != null) {
      String merchant = ippbMatch.group(1)?.trim() ?? '';
      if (merchant.isNotEmpty && merchant.length > 2) return merchant;
    }

    // 6. Cosmos/Generic Pattern: "for MERCHANT-" or "for MERCHANT."
    // Example: "debited by INR 220 for MSEDCL-160220725411"
    final cosmosPattern = RegExp(
      r'\bfor\s+([A-Z][A-Z\s]+?)(?:-|\.|$)',
      caseSensitive: false,
    );
    final cosmosMatch = cosmosPattern.firstMatch(text);
    if (cosmosMatch != null) {
      String merchant = cosmosMatch.group(1)?.trim() ?? '';
      // Remove trailing numbers
      merchant = merchant.replaceAll(RegExp(r'\d+$'), '').trim();
      if (merchant.isNotEmpty && merchant.length > 2) return merchant;
    }

    // 7. MAHABANK/Generic Credit Pattern: "by MERCHANT" (credit transactions)
    // Example: "credited by INR 300.00 on 17-DEC-2024 by APB Credit Through PFMS"
    if (text.toLowerCase().contains('credit')) {
      final byPattern = RegExp(
        r'\bby\s+([A-Z][A-Za-z\s]+?)(?:\s+A\d|$)',
        caseSensitive: false,
      );
      final byMatch = byPattern.firstMatch(text);
      if (byMatch != null) {
        String merchant = byMatch.group(1)?.trim() ?? '';
        if (merchant.isNotEmpty && merchant.length > 2) return merchant;
      }
    }

    // ========================================
    // GENERIC FALLBACK PATTERNS
    // ========================================

    final words = _tokenizeAndNormalize(text);
    if (words.isEmpty) return '';

    // Try trigger words approach
    final triggers = {
      'to',
      'at',
      'paid',
      'by',
      'via',
      'towards',
      'merchant',
      'vpa',
      'payee',
      'trf',
      'debit',
      'credited',
      'credit',
    };
    final stopWords = {'using', 'from', 'with', 'via', 'through'};

    for (int i = 0; i < words.length; i++) {
      if (triggers.contains(words[i])) {
        final buffer = <String>[];
        for (int j = i + 1; j < words.length && buffer.length < 6; j++) {
          final tok = words[j];
          if (tok.isEmpty) break;
          if (_commonBanks.contains(tok)) break;
          if (tok == 'rs' || tok == 'inr' || RegExp(r'^\d').hasMatch(tok))
            break;
          if (tok.length <= 2 && RegExp(r'^[^a-z0-9]+$').hasMatch(tok)) break;
          if (stopWords.contains(tok)) continue;
          buffer.add(tok);
        }
        if (buffer.isNotEmpty) {
          return buffer.join(' ');
        }
      }
    }

    // Domain/VPA patterns
    for (final tok in words) {
      if (tok.contains('@') || tok.contains('.com') || tok.contains('vpa')) {
        return tok;
      }
    }

    // Last resort: reasonable word candidates
    final candidates = words
        .where(
          (w) =>
              w.length > 3 &&
              RegExp(r'[a-z]').hasMatch(w) &&
              !w.contains(RegExp(r'\d{3,}')),
        )
        .toList();
    if (candidates.isNotEmpty) {
      return candidates.take(3).join(' ');
    }

    return '';
  }

  // Clean parsed amount string to plain number (returns empty if fails)
  String _cleanParsedAmount(String rawAmount) {
    if (rawAmount.isEmpty) return '';

    // Split by spaces and try to find a valid amount in each token
    // This handles cases like "rs.1.00 credited 231125" -> should extract "1.00"
    final tokens = rawAmount.split(' ');

    for (final token in tokens) {
      var s = token.toLowerCase();
      // Remove currency symbols but keep digits and dots
      s = s.replaceAll(RegExp(r'[^0-9.]'), '');

      // CRITICAL FIX: Remove leading/trailing dots (from "rs.", "inr.", etc.)
      // Without this, "rs.5.00" becomes ".5.00" which parses as 0.50!
      s = s.replaceAll(RegExp(r'^\.+|\.+$'), '');

      if (s.isEmpty) continue;

      // Handle multiple dots - keep only first
      final dots = '.'.allMatches(s).length;
      if (dots > 1) {
        final firstDot = s.indexOf('.');
        s = s.replaceAll('.', '');
        if (firstDot >= 0 && firstDot < s.length) {
          s = s.substring(0, firstDot) + '.' + s.substring(firstDot);
        }
      }

      // Try to parse as double
      try {
        final d = double.parse(s);
        // Reject if <= 0 or looks like a date (e.g., 231125, 26oct25 -> 2625)
        if (d <= 0 || d > 100000)
          continue; // Skip if too large (likely date/transaction ID)

        // Valid amount found! Format and return
        return d.toStringAsFixed(d.truncateToDouble() == d ? 0 : 2);
      } catch (e) {
        // Not parseable, try next token
        continue;
      }
    }

    // No valid amount found in any token
    return '';
  }

  // Remove leading app name or sender identifiers from SMS notifications.
  String _stripAppAndSender(String text) {
    var cleaned = text;

    // 1. Strip generic app headers if they appear at the start
    final appHeaders = [
      'Messages',
      'SMS',
      'Message',
      'Notification',
      'Null',
      'null',
    ];
    for (final header in appHeaders) {
      // Case-insensitive check for header at start followed by space or colon
      if (cleaned.toLowerCase().startsWith(header.toLowerCase())) {
        // Remove the header and any immediate following separator
        cleaned = cleaned.replaceFirst(
          RegExp('^${RegExp.escape(header)}[:\\s-]*', caseSensitive: false),
          '',
        );
      }
    }
    cleaned = cleaned.trim();

    // 2. Strip Sender IDs (e.g. "JM-HDFCBK", "VK-SBIUPI", "HDFC-CS", "HDFC :", "57575701")
    // Pattern:
    // - XX-YYYYYY (Standard hyphenated Sender ID like "JM-HDFCBK")
    // - XXXXX : (Sender name with colon like "HDFC :")
    // - AAAAAA (Shortcodes often 5-8 digits)
    // We look for these at the START of the string, followed by colon/hyphen/space.
    // We must be careful NOT to strip "Rs." or "INR" or "Paid".

    // Pattern 1: Hyphenated sender IDs (e.g. AD-HDFCBK, HDFC-CS)
    // Matches: Start, 2+ chars, hyphen, 2+ chars, optional separators
    final senderIdHyphenated = RegExp(
      r'^[A-Za-z0-9]{2,}-[A-Za-z0-9]{2,}[:\\s-]*',
    );
    if (senderIdHyphenated.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(senderIdHyphenated, '').trim();
    }

    // Pattern 2: Short sender names followed by colon (e.g. HDFC :, SBI :)
    // Matches: Start, 2-10 chars (letters/numbers), whitespace + colon
    // Must be short enough to not be part of the actual message
    final senderIdColon = RegExp(r'^[A-Za-z]{2,10}\s*:', caseSensitive: false);
    if (senderIdColon.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(senderIdColon, '').trim();
    }

    // Pattern 3: Numeric shortcodes (e.g. 575757) followed by colon/hyphen
    // We require a separator here to avoid stripping numbers that are part of the message
    final shortcodePattern = RegExp(r'^\d{5,8}[:\\s-]+');
    if (shortcodePattern.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(shortcodePattern, '').trim();
    }

    return cleaned.trim();
  }

  // ----------------------------
  // Run inference (ML) and fallback merge
  // ----------------------------
  PredictionResult predict(String smsText) {
    final cleanedSMS = _stripAppAndSender(smsText).trim();
    if (_interpreter == null || _wordIndex.isEmpty || _idx2tag.isEmpty) {
      print("❌ Model/tokenizers not loaded properly. Running fallback only.");
      final fallbackAmountRaw = _fallbackExtractAmount(cleanedSMS);
      final amount = _cleanParsedAmount(fallbackAmountRaw);
      final merchant = _fallbackExtractMerchant(cleanedSMS);
      final bank = _fallbackExtractBank(cleanedSMS);
      return PredictionResult(
        merchant: merchant,
        amount: amount,
        bankName: bank,
        words: _tokenizeAndNormalize(cleanedSMS),
        tags: [],
        usedFallback: true,
      );
    }

    print("\n" + "─" * 60);
    print("🔍 PROCESSING SMS (ML -> Fallback hybrid)");
    print("─" * 60);
    print("📝 Original: $smsText");

    // tokenize & sequences
    final words = _tokenizeAndNormalize(cleanedSMS);
    if (words.isEmpty) {
      print("⚠️  No tokens after preprocessing. Running fallback only.");
      final fallbackAmountRaw = _fallbackExtractAmount(cleanedSMS);
      final amount = _cleanParsedAmount(fallbackAmountRaw);
      final merchant = _fallbackExtractMerchant(cleanedSMS);
      final bank = _fallbackExtractBank(cleanedSMS);
      return PredictionResult(
        merchant: merchant,
        amount: amount,
        bankName: bank,
        words: [],
        tags: [],
        usedFallback: true,
      );
    }

    final seq = _textsToSequences(words);
    final padded = _padSequence(seq, _maxLen);

    // DEBUG: Show tokenization details
    print("\n🔧 TOKENIZATION DEBUG:");
    print(
      "   Words (${words.length}): ${words.take(10).join(' ')}${words.length > 10 ? '...' : ''}",
    );
    print(
      "   Sequences (first 10): ${seq.take(10).join(', ')}${seq.length > 10 ? '...' : ''}",
    );
    print("   Padded length: ${padded.length}");
    print(
      "   OOV count: ${seq.where((idx) => idx == _oovToken).length}/${seq.length}",
    );

    // Input expects 2D: [1, maxLen]
    final input = [padded];

    // Prepare output container
    final tagCount = _idx2tag.length == 0 ? 6 : _idx2tag.length;
    // Output shape expected [1, maxLen, tagCount]
    final output = List.generate(
      1,
      (_) => List.generate(_maxLen, (_) => List<double>.filled(tagCount, 0.0)),
    );

    // DEBUG: Show shapes
    print("\n📐 MODEL SHAPES:");
    print("   Input shape: [1, ${padded.length}]");
    print("   Output shape: [1, $_maxLen, $tagCount]");
    print("   Expected tags: $_idx2tag");

    // Run interpreter - wrapped to catch runtime problems
    try {
      _interpreter!.run(input, output);
      print("✓ Inference completed (ML)");

      // DEBUG: Show raw predictions for first few tokens
      print("\n🎲 RAW PREDICTIONS (first 5 tokens):");
      for (int i = 0; i < 5 && i < words.length; i++) {
        final probs = output[0][i];
        print("   Token '${words[i]}' probabilities:");
        for (int j = 0; j < probs.length; j++) {
          final tag = _idx2tag[j] ?? 'UNKNOWN';
          print("      [$j] $tag: ${probs[j].toStringAsFixed(4)}");
        }
      }
    } catch (e) {
      print("❌ Inference failed: $e");
      print("→ Falling back to regex heuristics only.");
      final fallbackAmountRaw = _fallbackExtractAmount(cleanedSMS);
      final amount = _cleanParsedAmount(fallbackAmountRaw);
      final merchant = _fallbackExtractMerchant(cleanedSMS);
      final bank = _fallbackExtractBank(cleanedSMS);
      return PredictionResult(
        merchant: merchant,
        amount: amount,
        bankName: bank,
        words: words,
        tags: [],
        usedFallback: true,
      );
    }

    // decode predictions (argmax per token)
    final predictedTags = <String>[];
    final bufferMerchantParts = <String>[];
    final bufferAmountParts = <String>[];
    final bufferBankParts = <String>[];
    String mlMerchant = '';
    String mlAmount = '';
    String mlBank = '';

    for (int i = 0; i < words.length && i < _maxLen; i++) {
      final tokenProbs = output[0][i];
      // argmax
      int maxIdx = 0;
      double maxProb = tokenProbs.isNotEmpty ? tokenProbs[0] : 0.0;
      for (int j = 1; j < tokenProbs.length; j++) {
        if (tokenProbs[j] > maxProb) {
          maxProb = tokenProbs[j];
          maxIdx = j;
        }
      }
      final tag = _idx2tag[maxIdx] ?? 'O';
      predictedTags.add(tag);

      // Build entities from tags (improved IOB logic for ALL entity types)

      // MERCHANT handling
      if (tag == 'B-MERCHANT') {
        // Flush previous merchant if exists
        if (bufferMerchantParts.isNotEmpty) {
          mlMerchant =
              (mlMerchant +
                      (mlMerchant.isEmpty ? '' : ' ') +
                      bufferMerchantParts.join(' '))
                  .trim();
          bufferMerchantParts.clear();
        }
        // Start new merchant
        bufferMerchantParts.add(words[i]);
      } else if (tag == 'I-MERCHANT') {
        // Continue merchant sequence
        bufferMerchantParts.add(words[i]);
      } else {
        // Non-merchant tag: flush merchant buffer if any
        if (bufferMerchantParts.isNotEmpty) {
          mlMerchant =
              (mlMerchant +
                      (mlMerchant.isEmpty ? '' : ' ') +
                      bufferMerchantParts.join(' '))
                  .trim();
          bufferMerchantParts.clear();
        }
      }

      // AMOUNT handling (now handles I-AMOUNT too!)
      if (tag == 'B-AMOUNT') {
        // Flush previous amount if exists
        if (bufferAmountParts.isNotEmpty) {
          mlAmount =
              (mlAmount +
                      (mlAmount.isEmpty ? '' : ' ') +
                      bufferAmountParts.join(' '))
                  .trim();
          bufferAmountParts.clear();
        }
        // Start new amount
        bufferAmountParts.add(words[i]);
      } else if (tag == 'I-AMOUNT') {
        // Continue amount sequence
        bufferAmountParts.add(words[i]);
      } else {
        // Non-amount tag: flush amount buffer if any
        if (bufferAmountParts.isNotEmpty) {
          mlAmount =
              (mlAmount +
                      (mlAmount.isEmpty ? '' : ' ') +
                      bufferAmountParts.join(' '))
                  .trim();
          bufferAmountParts.clear();
        }
      }

      // BANK handling (now handles I-BANK too!)
      if (tag == 'B-BANK') {
        // Flush previous bank if exists
        if (bufferBankParts.isNotEmpty) {
          mlBank =
              (mlBank + (mlBank.isEmpty ? '' : ' ') + bufferBankParts.join(' '))
                  .trim();
          bufferBankParts.clear();
        }
        // Start new bank
        bufferBankParts.add(words[i]);
      } else if (tag == 'I-BANK') {
        // Continue bank sequence
        bufferBankParts.add(words[i]);
      } else {
        // Non-bank tag: flush bank buffer if any
        if (bufferBankParts.isNotEmpty) {
          mlBank =
              (mlBank + (mlBank.isEmpty ? '' : ' ') + bufferBankParts.join(' '))
                  .trim();
          bufferBankParts.clear();
        }
      }
    }

    // Flush all buffers at end
    if (bufferMerchantParts.isNotEmpty) {
      mlMerchant =
          (mlMerchant +
                  (mlMerchant.isEmpty ? '' : ' ') +
                  bufferMerchantParts.join(' '))
              .trim();
      bufferMerchantParts.clear();
    }
    if (bufferAmountParts.isNotEmpty) {
      mlAmount =
          (mlAmount +
                  (mlAmount.isEmpty ? '' : ' ') +
                  bufferAmountParts.join(' '))
              .trim();
      bufferAmountParts.clear();
    }
    if (bufferBankParts.isNotEmpty) {
      mlBank =
          (mlBank + (mlBank.isEmpty ? '' : ' ') + bufferBankParts.join(' '))
              .trim();
      bufferBankParts.clear();
    }

    print("🎯 RAW ML EXTRACTION (before cleaning):");
    print("   Merchant: '$mlMerchant'");
    print("   Amount: '$mlAmount'");
    print("   Bank: '$mlBank'");

    // === POST-PROCESSING: Clean extracted entities ===
    // Generalized cleaning handles various SMS formats from different banks
    final cleaned = EntityCleaner.cleanAll(
      amount: mlAmount,
      merchant: mlMerchant,
      bank: mlBank,
      originalSms: cleanedSMS,
    );

    mlAmount = cleaned['amount']!;
    mlMerchant = cleaned['merchant']!;
    mlBank = cleaned['bank']!;

    print("\n✨ AFTER POST-PROCESSING:");
    print("   Merchant: '$mlMerchant'");
    print("   Amount: '$mlAmount'");
    print("   Bank: '$mlBank'\n");

    // Clean ML amount
    final cleanedMlAmount = _cleanParsedAmount(mlAmount);

    // Run fallback extraction in background (same text)
    final fallbackAmtRaw = _fallbackExtractAmount(cleanedSMS);
    final fallbackAmount = _cleanParsedAmount(fallbackAmtRaw);
    final fallbackMerchant = _fallbackExtractMerchant(cleanedSMS);
    final fallbackBank = _fallbackExtractBank(cleanedSMS);

    // ML-First Strategy: Trust ML predictions, only use fallback as safety net
    // Fallback only kicks in when ML completely fails or produces invalid data

    // Amount validation: Only check if parseable and positive
    bool mlAmountValid = cleanedMlAmount.isNotEmpty;
    if (mlAmountValid) {
      final mlAmt = double.tryParse(cleanedMlAmount);
      // Only reject if clearly invalid (unparseable, zero, or negative)
      if (mlAmt == null || mlAmt <= 0) {
        mlAmountValid = false;
      }
      // REMOVED: No longer compare with fallback or use heuristics
      // Trust the ML model (99% recall) over regex
    }

    // Merchant validation: Accept any non-empty result
    // No validation needed - if ML found something, use it

    // Bank validation: Only reject obvious garbage words
    bool mlBankValid =
        mlBank.isNotEmpty &&
        !mlBank.contains('credited') &&
        !mlBank.contains('debited') &&
        !mlBank.contains('paid') &&
        !mlBank.contains('received');
    // REMOVED: No longer check against common banks list
    // This was causing valid bank names to be rejected

    // Decision logic: ML first, fallback only when ML fails
    var finalAmount = mlAmountValid ? cleanedMlAmount : fallbackAmount;
    var finalMerchant = mlMerchant.isNotEmpty ? mlMerchant : fallbackMerchant;
    var finalBank = mlBankValid ? mlBank : fallbackBank;

    // Track fallback usage only when actually used
    bool usedFallback = false;
    if (!mlAmountValid && fallbackAmount.isNotEmpty) usedFallback = true;
    if (mlMerchant.isEmpty && fallbackMerchant.isNotEmpty) usedFallback = true;
    if (!mlBankValid && fallbackBank.isNotEmpty) usedFallback = true;

    // Very small heuristics: if ML gave nonsense (like 'on' or 'date' as amount), fallback
    if (finalAmount.isEmpty && fallbackAmount.isNotEmpty) {
      finalAmount = fallbackAmount;
    }

    // Logging results nicely
    print("\n📊 RESULTS:");
    print("─" * 60);
    for (int i = 0; i < words.length; i++) {
      final t = i < predictedTags.length ? predictedTags[i] : 'O';
      final emoji = t.contains('AMOUNT')
          ? '💰'
          : t.contains('MERCHANT')
          ? '🏪'
          : t.contains('BANK')
          ? '🏦'
          : '  ';
      print("$emoji ${words[i].padRight(20)} → $t");
    }

    print("\n🎯 EXTRACTED ENTITIES (ML / fallback merge):");
    print("─" * 60);
    print("ML Merchant: '$mlMerchant'");
    print("Fallback Merchant: '$fallbackMerchant'");
    print(
      "→ Final Merchant: '${finalMerchant.isEmpty ? '(not found)' : finalMerchant}'",
    );
    print("ML Amount: '$mlAmount' -> cleaned: '$cleanedMlAmount'");
    print("Fallback Amount: '$fallbackAmtRaw' -> cleaned: '$fallbackAmount'");
    print(
      "→ Final Amount: '${finalAmount.isEmpty ? '(not found)' : finalAmount}'",
    );
    print("ML Bank: '$mlBank'");
    print("Fallback Bank: '$fallbackBank'");
    print("→ Final Bank: '${finalBank.isEmpty ? '(not found)' : finalBank}'");
    print("Used fallback? $usedFallback");
    print("─" * 60 + "\n");

    return PredictionResult(
      merchant: finalMerchant.trim(),
      amount: finalAmount.trim(),
      bankName: finalBank.trim(),
      words: words,
      tags: predictedTags,
      usedFallback: usedFallback,
    );
  }

  // A convenient detailed debugging wrapper
  Map<String, dynamic> predictDetailed(String smsText) {
    final res = predict(smsText);
    final pairs = <Map<String, String>>[];
    for (int i = 0; i < res.words.length; i++) {
      pairs.add({
        'word': res.words[i],
        'tag': i < res.tags.length ? res.tags[i] : 'O',
      });
    }
    return {
      'merchant': res.merchant,
      'amount': res.amount,
      'bank': res.bankName,
      'usedFallback': res.usedFallback,
      'word_tag_pairs': pairs,
      'raw_words': res.words,
      'raw_tags': res.tags,
    };
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _wordIndex.clear();
    _idx2tag.clear();
    print("🗑️  ML Service disposed");
  }
}
