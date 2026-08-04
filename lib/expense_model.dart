class Expense {
  final int? id; // Nullable for new expenses that don't have an ID yet
  final String title; // The merchant name (e.g., "Zomato")
  final double amount;
  final DateTime date; // The precise date/time of the transaction
  final String category; // e.g., "Food", "Travel" (we'll set "Uncategorized")
  final String type; // "debit" or "credit"
  final String bankName; // e.g., "HDFC", "Paytm Payments Bank"

  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.type,
    required this.bankName,
  });

  // --- Conversion for Database ---

  // Converts an Expense object into a Map object.
  // This is used BEFORE inserting into the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date
          .millisecondsSinceEpoch, // Convert DateTime to integer for SQL
      'category': category,
      'type': type,
      'bankName': bankName,
    };
  }

  // Converts a Map object (from the database) into an Expense object.
  // This is used AFTER reading from the database.
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.fromMillisecondsSinceEpoch(
          map['date']), // Convert integer back to DateTime
      category: map['category'],
      type: map['type'],
      bankName: map['bankName'],
    );
  }

  @override
  String toString() {
    return 'Expense{id: $id, title: $title, amount: $amount, date: $date, category: $category, type: $type, bankName: $bankName}';
  }
}

