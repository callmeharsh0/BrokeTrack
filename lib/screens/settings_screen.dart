import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  int _totalExpenses = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final expenses = await dbHelper.getAllExpenses();
    setState(() {
      _totalExpenses = expenses.length;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 20),

                // App Info Section
                _buildSectionHeader('App Information'),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.receipt_long,
                  title: 'Total Transactions',
                  subtitle: '$_totalExpenses transactions tracked',
                  color: const Color(0xFF6366F1),
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.table_chart,
                  title: 'Export to Sheets',
                  subtitle: 'Download transactions as CSV',
                  color: const Color(0xFF10B981),
                  onTap: () => _exportToCSV(),
                ),

                const SizedBox(height: 32),

                // Data Management
                _buildSectionHeader('Data Management'),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.refresh,
                  title: 'Refresh Data',
                  subtitle: 'Reload all transactions',
                  color: const Color(0xFF3B82F6),
                  onTap: () async {
                    await _loadStats();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Data refreshed!')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.delete_outline,
                  title: 'Clear All Data',
                  subtitle: 'Delete all transactions',
                  color: const Color(0xFFEF4444),
                  onTap: () => _showClearDataDialog(),
                ),

                const SizedBox(height: 32),

                // About
                _buildSectionHeader('About'),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.info_outline,
                  title: 'Broketrack',
                  subtitle: 'Version 1.3.0',
                  color: const Color(0xFF8B5CF6),
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.auto_awesome,
                  title: 'AI-Powered',
                  subtitle: 'Using TFlite AI model for smart categorization',
                  color: const Color(0xFFF59E0B),
                ),

                const SizedBox(height: 40),

                // Footer
                Center(
                  child: Text(
                    'Made by Yourknowwho',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToCSV() async {
    try {
      // Get all expenses from database
      final expenses = await dbHelper.getAllExpenses();

      if (expenses.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No transactions to export'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
        return;
      }

      // Create CSV content
      final csvContent = StringBuffer();
      csvContent.writeln('Date,Merchant,Amount,Category,Type,Bank');

      for (final expense in expenses) {
        csvContent.writeln(
          '${expense.date},${_escapeCsv(expense.title)},${expense.amount},'
          '${_escapeCsv(expense.category)},${_escapeCsv(expense.type)},${_escapeCsv(expense.bankName)}',
        );
      }

      // Get downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage');
      }

      // Create file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/expenses_$timestamp.csv');
      await file.writeAsString(csvContent.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${file.path}'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> _showClearDataDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Clear All Data?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'This will permanently delete all your transactions. This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Delete All'),
              onPressed: () async {
                await dbHelper.deleteAllExpenses();
                await _loadStats();
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All data cleared!'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
