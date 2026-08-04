class Category {
  final String id;
  final String name;
  final String icon; // Emoji or icon name
  final String color; // Hex color code
  final bool isDefault;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'isDefault': isDefault ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      color: map['color'],
      isDefault: map['isDefault'] == 1,
    );
  }
}

// Default Categories
class DefaultCategories {
  static final List<Category> categories = [
    Category(
      id: 'food',
      name: 'Food & Dining',
      icon: '🍔',
      color: '#F59E0B',
      isDefault: true,
    ),
    Category(
      id: 'transport',
      name: 'Transport',
      icon: '🚗',
      color: '#3B82F6',
      isDefault: true,
    ),
    Category(
      id: 'shopping',
      name: 'Shopping',
      icon: '🛒',
      color: '#EC4899',
      isDefault: true,
    ),
    Category(
      id: 'healthcare',
      name: 'Healthcare',
      icon: '💊',
      color: '#EF4444',
      isDefault: true,
    ),
    Category(
      id: 'entertainment',
      name: 'Entertainment',
      icon: '🎬',
      color: '#8B5CF6',
      isDefault: true,
    ),
    Category(
      id: 'bills',
      name: 'Bills & Utilities',
      icon: '📱',
      color: '#F97316',
      isDefault: true,
    ),
    Category(
      id: 'salary',
      name: 'Salary/Income',
      icon: '💰',
      color: '#10B981',
      isDefault: true,
    ),
    Category(
      id: 'education',
      name: 'Education',
      icon: '🎓',
      color: '#06B6D4',
      isDefault: true,
    ),
    Category(
      id: 'housing',
      name: 'Housing',
      icon: '🏠',
      color: '#84CC16',
      isDefault: true,
    ),
    Category(
      id: 'other',
      name: 'Other',
      icon: '✨',
      color: '#64748B',
      isDefault: true,
    ),
  ];

  // Auto-categorization rules
  static String getCategoryForMerchant(String merchant) {
    final lowerMerchant = merchant.toLowerCase();
    
    // Food & Dining
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
    
    // Transport
    if (lowerMerchant.contains('uber') ||
        lowerMerchant.contains('ola') ||
        lowerMerchant.contains('rapido') ||
        lowerMerchant.contains('metro') ||
        lowerMerchant.contains('petrol') ||
        lowerMerchant.contains('fuel') ||
        lowerMerchant.contains('parking')) {
      return 'transport';
    }
    
    // Shopping
    if (lowerMerchant.contains('amazon') ||
        lowerMerchant.contains('flipkart') ||
        lowerMerchant.contains('myntra') ||
        lowerMerchant.contains('ajio') ||
        lowerMerchant.contains('meesho') ||
        lowerMerchant.contains('shop')) {
      return 'shopping';
    }
    
    // Entertainment
    if (lowerMerchant.contains('netflix') ||
        lowerMerchant.contains('prime') ||
        lowerMerchant.contains('hotstar') ||
        lowerMerchant.contains('spotify') ||
        lowerMerchant.contains('movie') ||
        lowerMerchant.contains('game')) {
      return 'entertainment';
    }
    
    // Bills
    if (lowerMerchant.contains('electricity') ||
        lowerMerchant.contains('water') ||
        lowerMerchant.contains('internet') ||
        lowerMerchant.contains('mobile') ||
        lowerMerchant.contains('recharge') ||
        lowerMerchant.contains('bill')) {
      return 'bills';
    }
    
    return 'other';
  }
}
