import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../expense_model.dart';
import '../models/category_model.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const ExpenseCard({
    Key? key,
    required this.expense,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('MMM d, h:mm a').format(expense.date);
    final Color amountColor = expense.type == 'debit' 
        ? Theme.of(context).colorScheme.error 
        : const Color(0xFF10B981);
    final String amountPrefix = expense.type == 'debit' ? '-' : '+';
    
    // Get category info
    final categoryId = expense.category.toLowerCase();
    final category = DefaultCategories.categories.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => DefaultCategories.categories.last, // Default to 'other'
    );
    
    // Parse category color
    final categoryColor = Color(
      int.parse(category.color.replaceFirst('#', '0xFF')),
    );

    return Slidable(
      key: ValueKey(expense.id),
      
      // Left side - Edit action
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Edit',
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      
      // Right side - Delete action
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Delete',
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Category Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      category.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Expense Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category.name,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: categoryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${expense.bankName}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$amountPrefix₹${expense.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: amountColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        expense.type == 'debit' ? 'Expense' : 'Income',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
