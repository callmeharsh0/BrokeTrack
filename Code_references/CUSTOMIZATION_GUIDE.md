# UI Customization Guide

This guide shows you how to easily customize the expense tracker UI. Everything is modular and well-organized!

## 🎨 Color Scheme

**File**: `lib/utils/theme.dart`

### Change Main Colors

```dart
// Line 7-9: Primary colors
static const Color primaryPurple = Color(0xFF6366F1);  // Main brand color
static const Color primaryTeal = Color(0xFF14B8A6);    // Secondary color
static const Color accentOrange = Color(0xFFF59E0B);   // Accent color
```

**Popular Color Schemes**:

```dart
// Blue & Orange (Energetic)
primaryPurple = Color(0xFF2563EB)
primaryTeal = Color(0xFFF97316)

// Green & Teal (Calm)
primaryPurple = Color(0xFF10B981)
primaryTeal = Color(0xFF06B6D4)

// Pink & Purple (Vibrant)
primaryPurple = Color(0xFFEC4899)
primaryTeal = Color(0xFF8B5CF6)
```

### Change Amount Colors

```dart
// Line 17-19
static const Color successGreen = Color(0xFF10B981);  // Income color
static const Color errorRed = Color(0xFFEF4444);      // Expense color
```

---

## 🔤 Fonts

**File**: `lib/utils/theme.dart`

### Change Typography

```dart
// Line 56-89: Replace fonts
textTheme: GoogleFonts.interTextTheme()  // Try: poppinsTextTheme(), latoTextTheme(), etc.

// Or mix and match:
displayLarge: GoogleFonts.montserrat(...)  // Headings
bodyLarge: GoogleFonts.roboto(...)         // Body text
```

**Available Google Fonts**: Poppins, Inter, Roboto, Lato, Montserrat, Open Sans, Raleway, etc.

---

## 📂 Categories

**File**: `lib/models/category_model.dart`

### Add New Category

```dart
// In the categories list (line 31):
Category(
  id: 'pets',              // Unique ID
  name: 'Pet Care',        // Display name
  icon: '🐕',              // Any emoji
  color: '#F97316',        // Hex color
  isDefault: true,
),
```

### Change Existing Category

```dart
Category(
  id: 'food',
  name: 'Restaurants',     // Rename
  icon: '🍕',              // Change icon
  color: '#FF6B6B',        // Change color
),
```

### Auto-Categorization Rules

```dart
// In getCategoryForMerchant() method (line 101):
if (lowerMerchant.contains('gym') || 
    lowerMerchant.contains('fitness')) {
  return 'fitness';  // Your category ID
}
```

---

## 💳 Expense Card Design

**File**: `lib/widgets/expense_card.dart`

### Card Styling

```dart
// Line 107: Border radius
borderRadius: BorderRadius.circular(16),  // Try: 8, 12, 20, 24

// Line 109: Border
side: BorderSide(
  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
  width: 1,  // Try: 0 (no border), 2 (thicker)
),
```

### Icon Container

```dart
// Line 121-127: Category icon styling
Container(
  width: 48,           // Size: try 40, 56, 64
  height: 48,
  decoration: BoxDecoration(
    color: categoryColor.withOpacity(0.15),  // Background transparency
    borderRadius: BorderRadius.circular(12),  // Icon corner radius
  ),
)
```

### Text Sizes

```dart
// Line 143: Merchant name
fontSize: 16,  // Default from theme, or specify: 14, 18, 20

// Line 152: Category badge
fontSize: 11,  // Try: 10, 12

// Line 168: Date
fontSize: 12,  // Try: 11, 13
```

---

## 🎯 App Bar

**File**: `lib/main.dart`

### Gradient Colors

```dart
// Line 421-424: Change app bar gradient
flexibleSpace: Container(
  decoration: const BoxDecoration(
    gradient: AppTheme.primaryGradient,  // Uses theme colors
  ),
),
```

### Custom Gradient

```dart
gradient: LinearGradient(
  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],  // Custom colors
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
),
```

### Title Style

```dart
// Line 429-433
const Text(
  'AI Expense Tracker',  // Change text
  style: TextStyle(
    color: Colors.white,
    fontSize: 22,          // Change size
    fontWeight: FontWeight.bold,
  ),
),
```

---

## 🔘 Floating Action Button

**File**: `lib/main.dart`

### Button Style

```dart
// Line 465-471
FloatingActionButton.extended(
  onPressed: () => _showExpenseDialog(),
  icon: const Icon(Icons.add),
  label: const Text('Add Expense'),  // Change label
  backgroundColor: AppTheme.primaryPurple,  // Change color
  foregroundColor: Colors.white,
)
```

### Make it Regular FAB

```dart
// Replace with:
FloatingActionButton(
  onPressed: () => _showExpenseDialog(),
  child: const Icon(Icons.add),
  backgroundColor: AppTheme.primaryPurple,
)
```

---

## 📊 Spacing & Layout

### Card Spacing

**File**: `lib/widgets/expense_card.dart`

```dart
// Line 101: Margin between cards
margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
// Try: vertical: 8 (more space), vertical: 4 (less space)

// Line 115: Padding inside card
padding: const EdgeInsets.all(16),
// Try: 12, 20, 24
```

### List Padding

**File**: `lib/main.dart`

```dart
// Line 542: List padding
padding: const EdgeInsets.only(top: 8, bottom: 80),
// Adjust top/bottom spacing
```

---

## 🌙 Dark Mode

**File**: `lib/main.dart`

### Enable Dark Mode

```dart
// Line 24-26
return MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ThemeMode.dark,  // Change to: .light, .dark, or .system
)
```

### System-Based Theme

```dart
themeMode: ThemeMode.system,  // Follows device settings
```

---

## 🎭 Swipe Action Colors

**File**: `lib/widgets/expense_card.dart`

### Edit Action (Left Swipe)

```dart
// Line 53-59
SlidableAction(
  backgroundColor: Theme.of(context).colorScheme.primary,  // Change color
  foregroundColor: Colors.white,
  icon: Icons.edit_rounded,      // Change icon
  label: 'Edit',                 // Change label
)
```

### Delete Action (Right Swipe)

```dart
// Line 68-74
SlidableAction(
  backgroundColor: Theme.of(context).colorScheme.error,  // Change color
  icon: Icons.delete_rounded,    // Change icon
  label: 'Delete',               // Change label
)
```

---

## 🔖 Badges & Tags

**File**: `lib/widgets/expense_card.dart`

### Category Badge

```dart
// Line 155-165: Category badge styling
Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),  // Size
  decoration: BoxDecoration(
    color: categoryColor.withOpacity(0.1),  // Background
    borderRadius: BorderRadius.circular(6),  // Corner radius
  ),
)
```

### Transaction Type Badge

```dart
// Line 202-211
Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(
    color: amountColor.withOpacity(0.1),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text(
    expense.type == 'debit' ? 'Expense' : 'Income',  // Change labels
  ),
)
```

---

## ⚙️ Advanced Customizations

### Add Elevation to Cards

```dart
// In expense_card.dart, Card widget:
elevation: 2,  // Try: 0 (flat), 4, 8 (more shadow)
```

### Rounded Corners Everywhere

```dart
// In theme.dart, change all BorderRadius.circular() values:
BorderRadius.circular(12),  // Less rounded
BorderRadius.circular(20),  // More rounded
```

### Icon Pack

```dart
// Change from emoji to Material Icons:
// In category_model.dart:
icon: 'restaurant',  // Icon name instead of emoji

// Then in expense_card.dart, replace Text widget with:
Icon(Icons.restaurant, size: 24)
```

---

## 💡 Tips

1. **Always test changes immediately** - Hot reload works for most UI changes
2. **Change theme.dart first** - Gets you 80% of the way
3. **Keep backups** - Git commit before major changes
4. **Use consistent spacing** - Stick to multiples of 4 or 8 (4, 8, 12, 16, 20, 24)
5. **Accessibility** - Keep text contrast ratio above 4.5:1

---

## 🚀 Quick Start Examples

### Example 1: Make it Blue

```dart
// theme.dart, line 7-8
primaryPurple = Color(0xFF2563EB)
primaryTeal = Color(0xFF3B82F6)
```

### Example 2: Bigger Text

```dart
// theme.dart, line 56-90
// Add to each text style:
fontSize: 18,  // Instead of 16
```

### Example 3: More Spacing

```dart
// expense_card.dart, line 101
margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10)

// expense_card.dart, line 115
padding: EdgeInsets.all(20)
```

### Example 4: Flat Design

```dart
// theme.dart, line 107
elevation: 0,  // No shadows

// expense_card.dart, remove border:
side: BorderSide.none,
```

---

## 📝 File Organization Reference

```
lib/
├── main.dart                    // Main screens & logic
├── utils/
│   └── theme.dart              // ⭐ All colors, fonts, styles
├── widgets/
│   └── expense_card.dart       // ⭐ Card design
├── models/
│   ├── category_model.dart     // ⭐ Categories & icons
│   └── expense_model.dart      // Data structure
└── services/
    ├── database_helper.dart    // Database
    └── ml_service.dart         // ML logic
```

**⭐ = Files you'll customize most**

---

## 🎨 Color Picker Tools

- **Coolors.co** - Generate palettes
- **Material Palette** - Get Material colors
- **ColorHunt** - Browse trending palettes

## 🎯 Icon Resources

- **Emojipedia** - Find perfect emojis
- **Material Icons** - Flutter built-in icons
- **FontAwesome** - More icon options

Happy customizing! 🎉
