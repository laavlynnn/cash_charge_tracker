import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as path;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(const CashChargeTrackerApp());
}

// ============================================================
// DARK CINEMATIC THEME
// ============================================================

class AppColors {
  static const background = Color(0xFF050814);
  static const surface = Color(0xFF0B1222);
  static const surface2 = Color(0xFF101A30);
  static const card = Color(0xFF0D172A);
  static const border = Color(0xFF263A67);
  static const purple = Color(0xFF8B5CF6);
  static const brightPurple = Color(0xFFA855F7);
  static const blue = Color(0xFF38BDF8);
  static const cyan = Color(0xFF2DD4BF);
  static const pink = Color(0xFFF472B6);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFFB7185);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const dim = Color(0xFF64748B);
}

class CashChargeTrackerApp extends StatelessWidget {
  const CashChargeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.purple,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.purple,
      secondary: AppColors.blue,
      surface: AppColors.surface,
    );

    return MaterialApp(
      title: 'Cash Charge Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          hintStyle: const TextStyle(color: AppColors.dim),
          labelStyle: const TextStyle(color: AppColors.muted),
          prefixIconColor: AppColors.muted,
          suffixIconColor: AppColors.muted,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.purple,
              width: 1.5,
            ),
          ),
        ),
        dividerColor: AppColors.border,
      ),
      home: const MainScreen(),
    );
  }
}

// ============================================================
// DATABASE
// ============================================================

class DatabaseHelper {
  static Database? _database;

  static final List<Map<String, double>> defaultRules = [
    {'min': 1, 'max': 100, 'charge': 5},
    {'min': 101, 'max': 1000, 'charge': 10},
    {'min': 1001, 'max': 1100, 'charge': 15},
    {'min': 1101, 'max': 2000, 'charge': 20},
    {'min': 2001, 'max': 2100, 'charge': 25},
    {'min': 2101, 'max': 3000, 'charge': 30},
    {'min': 3001, 'max': 3100, 'charge': 35},
    {'min': 3101, 'max': 4000, 'charge': 40},
    {'min': 4001, 'max': 4100, 'charge': 45},
    {'min': 4101, 'max': 5000, 'charge': 50},
  ];

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final String databaseFile;

    if (kIsWeb) {
      databaseFile = 'cash_charge_tracker_web.db';
    } else {
      final databasePath = await getDatabasesPath();
      databaseFile = path.join(
        databasePath,
        'cash_charge_tracker.db',
      );
    }

    return openDatabase(
      databaseFile,
      version: 3,
      onCreate: (db, version) async {
        await _createTransactionsTable(db);
        await _createRulesTable(db);
        await _insertDefaultRules(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN customerName TEXT',
          );
          await db.execute(
            'ALTER TABLE transactions ADD COLUMN customerContact TEXT',
          );
        }

        if (oldVersion < 3) {
          await _createRulesTable(db);
          await _insertDefaultRules(db);
        }
      },
    );
  }

  static Future<void> _createTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        charge REAL NOT NULL,
        date TEXT NOT NULL,
        customerName TEXT,
        customerContact TEXT
      )
    ''');
  }

  static Future<void> _createRulesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS charge_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        minAmount REAL NOT NULL,
        maxAmount REAL NOT NULL,
        charge REAL NOT NULL
      )
    ''');
  }

  static Future<void> _insertDefaultRules(DatabaseExecutor db) async {
    for (final rule in defaultRules) {
      await db.insert('charge_rules', {
        'minAmount': rule['min'],
        'maxAmount': rule['max'],
        'charge': rule['charge'],
      });
    }
  }

  static Future<int> insertTransaction(
    Map<String, dynamic> transaction,
  ) async {
    final db = await database;
    return db.insert('transactions', transaction);
  }

  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await database;
    return db.query('transactions', orderBy: 'date DESC');
  }

  static Future<int> deleteTransaction(int id) async {
    final db = await database;
    return db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<Map<String, dynamic>>> getChargeRules() async {
    final db = await database;
    return db.query(
      'charge_rules',
      orderBy: 'minAmount ASC',
    );
  }

  static Future<int> insertChargeRule({
    required double minAmount,
    required double maxAmount,
    required double charge,
  }) async {
    final db = await database;
    return db.insert('charge_rules', {
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      'charge': charge,
    });
  }

  static Future<int> updateChargeRule({
    required int id,
    required double minAmount,
    required double maxAmount,
    required double charge,
  }) async {
    final db = await database;
    return db.update(
      'charge_rules',
      {
        'minAmount': minAmount,
        'maxAmount': maxAmount,
        'charge': charge,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> deleteChargeRule(int id) async {
    final db = await database;
    return db.delete(
      'charge_rules',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> resetChargeRules() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('charge_rules');
      await _insertDefaultRules(txn);
    });
  }

  /// Calculates the service charge from the SAVED rules in SQLite.
  /// Amounts above the highest saved rule continue the pattern learned from
  /// the saved rules (see [ChargeEngine]); nothing is hard-coded.
  static Future<double?> calculateCharge(double amount) async {
    if (amount <= 0) return null;

    final rules = await getChargeRules();
    return ChargeEngine.calculate(rules, amount);
  }
}

// ============================================================
// CHARGE ENGINE (uses saved rules + derived continuation)
// ============================================================

class _ContinuationPattern {
  final double base; // highest amount covered by the saved rules
  final double lastCharge; // charge of the highest saved rule
  final double widthA; // width of the 1st rule in the repeating pair
  final double widthB; // width of the 2nd rule in the repeating pair
  final double stepA; // charge increase going INTO a type-A rule
  final double stepB; // charge increase going INTO a type-B rule

  const _ContinuationPattern({
    required this.base,
    required this.lastCharge,
    required this.widthA,
    required this.widthB,
    required this.stepA,
    required this.stepB,
  });
}

class ChargeEngine {
  static double _num(dynamic value) => (value as num).toDouble();

  static double _nonNegative(double value) => value < 0 ? 0.0 : value;

  static List<Map<String, dynamic>> sortRules(
    List<Map<String, dynamic>> rules,
  ) {
    final sorted = List<Map<String, dynamic>>.from(rules);
    sorted.sort(
      (a, b) => _num(a['minAmount']).compareTo(_num(b['minAmount'])),
    );
    return sorted;
  }

  /// Learns the continuation pattern from the LAST saved rules.
  ///
  /// The last two rules give the repeating pair of range widths, and the
  /// last three rules give the charge increase of each step. With the
  /// default rules this yields widths 100 / 900 and steps of +5, so
  /// 5,001-5,100 = 55, 5,101-6,000 = 60, and so on. If the saved rules
  /// change (for example steps of +10), the continuation changes too.
  static _ContinuationPattern? _patternFrom(List<Map<String, dynamic>> sorted) {
    if (sorted.isEmpty) return null;

    final count = sorted.length;
    final last = sorted[count - 1];
    final lastMin = _num(last['minAmount']);
    final lastMax = _num(last['maxAmount']);
    final lastCharge = _num(last['charge']);
    final lastWidth = lastMax - lastMin + 1;

    if (count == 1) {
      // One rule only: repeat its width and add its charge each step.
      return _ContinuationPattern(
        base: lastMax,
        lastCharge: lastCharge,
        widthA: lastWidth,
        widthB: lastWidth,
        stepA: lastCharge,
        stepB: lastCharge,
      );
    }

    final prev = sorted[count - 2];
    final prevWidth = _num(prev['maxAmount']) - _num(prev['minAmount']) + 1;
    final prevCharge = _num(prev['charge']);

    final stepB = _nonNegative(lastCharge - prevCharge);
    final stepA = count >= 3
        ? _nonNegative(prevCharge - _num(sorted[count - 3]['charge']))
        : stepB;

    return _ContinuationPattern(
      base: lastMax,
      lastCharge: lastCharge,
      widthA: prevWidth,
      widthB: lastWidth,
      stepA: stepA,
      stepB: stepB,
    );
  }

  /// Returns the service charge for [amount], or null if no rule covers it.
  /// Saved rules always win; the derived continuation is only used for
  /// amounts above the highest saved rule.
  static double? calculate(List<Map<String, dynamic>> rules, double amount) {
    if (amount <= 0 || rules.isEmpty) return null;

    final sorted = sortRules(rules);

    // 1. Saved rules (manual rules take priority over generated ones).
    // Centavo amounts that fall between two touching ranges (for example
    // 100.50 between 1-100 and 101-1,000) belong to the higher range.
    double? previousMax = _num(sorted.first['minAmount']) <= 1 ? 0.0 : null;
    for (final rule in sorted) {
      final min = _num(rule['minAmount']);
      final max = _num(rule['maxAmount']);

      final inRange = amount >= min && amount <= max;
      final inTouchingGap = previousMax != null &&
          amount > previousMax &&
          amount < min &&
          (min - previousMax) <= 1;

      if (inRange || inTouchingGap) {
        return _num(rule['charge']);
      }
      previousMax = max;
    }

    // 2. Above the highest saved rule: continue the derived pattern.
    final pattern = _patternFrom(sorted);
    if (pattern == null || amount <= pattern.base) {
      return null; // inside an uncovered gap between saved rules
    }

    final offset = amount - pattern.base;
    final period = pattern.widthA + pattern.widthB;
    final ratio = double.parse((offset / period).toStringAsFixed(9));
    var fullPeriods = ratio.ceil() - 1;
    if (fullPeriods < 0) fullPeriods = 0;

    final remainder = offset - (fullPeriods * period);

    var charge = pattern.lastCharge +
        (fullPeriods * (pattern.stepA + pattern.stepB)) +
        pattern.stepA;
    if (remainder > pattern.widthA + 0.000000001) {
      charge += pattern.stepB;
    }
    return charge;
  }

  /// The next [count] automatically generated ranges after the saved rules.
  static List<Map<String, double>> preview(
    List<Map<String, dynamic>> rules, {
    int count = 4,
  }) {
    final pattern = _patternFrom(sortRules(rules));
    if (pattern == null) return [];

    final result = <Map<String, double>>[];
    var min = pattern.base + 1;
    var charge = pattern.lastCharge;

    for (var i = 0; i < count; i++) {
      final isA = i % 2 == 0;
      final width = isA ? pattern.widthA : pattern.widthB;
      charge += isA ? pattern.stepA : pattern.stepB;
      final max = min + width - 1;
      result.add({'min': min, 'max': max, 'charge': charge});
      min = max + 1;
    }
    return result;
  }

  /// Ranges of whole-peso amounts that no saved rule covers.
  static List<List<double>> findGaps(List<Map<String, dynamic>> rules) {
    final sorted = sortRules(rules);
    final gaps = <List<double>>[];
    if (sorted.isEmpty) return gaps;

    final firstMin = _num(sorted.first['minAmount']);
    if (firstMin >= 2) {
      gaps.add([1.0, firstMin - 1]);
    }

    for (var i = 1; i < sorted.length; i++) {
      final previousMax = _num(sorted[i - 1]['maxAmount']);
      final nextMin = _num(sorted[i]['minAmount']);
      if (nextMin - previousMax >= 2) {
        gaps.add([previousMax + 1, nextMin - 1]);
      }
    }
    return gaps;
  }
}

// ============================================================
// HELPERS
// ============================================================

String peso(double value) => '₱${value.toStringAsFixed(2)}';

String compactPeso(double value) {
  if (value >= 1000000) {
    return '₱${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '₱${(value / 1000).toStringAsFixed(1)}K';
  }
  return peso(value);
}

String formatDate(String dateString) {
  final date = DateTime.parse(dateString);
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
          ? date.hour - 12
          : date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '${date.month}/${date.day}/${date.year} • '
      '$hour:$minute $period';
}

String shortDate(String dateString) {
  final date = DateTime.parse(dateString);
  return '${date.month}/${date.day}';
}

bool requiresCustomerInformation(String type, double amount) {
  return type == 'Cash In' && amount >= 5000;
}

/// Validates the FORMAT of a Philippine mobile number: 09XXXXXXXXX
/// (exactly 11 digits, digits only, starting with 09). This does not check
/// whether the number is active or belongs to a carrier.
String? validatePhMobileNumber(String value) {
  final number = value.trim();

  if (number.isEmpty) {
    return 'Contact number is required.';
  }
  if (!RegExp(r'^[0-9]+$').hasMatch(number)) {
    return 'Contact number must contain digits only.';
  }
  if (number.length != 11) {
    return 'Contact number must be exactly 11 digits (09XXXXXXXXX).';
  }
  if (!number.startsWith('09')) {
    return 'Contact number must start with 09 (09XXXXXXXXX).';
  }
  return null;
}

/// Allows only digits and one decimal point with at most 2 decimal places.
List<TextInputFormatter> moneyFormatters() => [
      FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*\.?[0-9]{0,2}')),
    ];

// ============================================================
// COMMON WIDGETS
// ============================================================

class GlowContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final List<Color>? gradient;
  final Color? color;
  final bool glow;

  const GlowContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.gradient,
    this.color,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? (color ?? AppColors.surface)
            : null,
        gradient: gradient == null
            ? null
            : LinearGradient(
                colors: gradient!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class NeonButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final List<Color>? colors;

  const NeonButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors ?? const [AppColors.purple, AppColors.brightPurple],
        ),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: (colors?.first ?? AppColors.purple)
                .withValues(alpha: 0.28),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GlowContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback? onDelete;
  final bool showDelete;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onDelete,
    this.showDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    final type = transaction['type'] as String;
    final amount = (transaction['amount'] as num).toDouble();
    final charge = (transaction['charge'] as num).toDouble();
    final isCashIn = type == 'Cash In';
    final accent = isCashIn ? AppColors.cyan : AppColors.pink;
    final customerName = transaction['customerName'] as String?;
    final customerContact = transaction['customerContact'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  isCashIn ? Icons.arrow_downward : Icons.arrow_upward,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatDate(transaction['date'] as String),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (showDelete)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.red,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _InfoRow(label: 'Amount', value: peso(amount)),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Service Charge',
                  value: peso(charge),
                  valueColor: AppColors.purple,
                ),
                if (customerName != null && customerName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Customer', value: customerName),
                ],
                if (customerContact != null &&
                    customerContact.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Contact', value: customerContact),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? AppColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  int refreshVersion = 0;

  // Changing the keys makes the visible tab reload its data after a
  // transaction is saved, so totals are never stale.
  List<Widget> get screens => [
        HomeScreen(key: ValueKey('home-$refreshVersion')),
        TransactionsScreen(key: ValueKey('history-$refreshVersion')),
        ReportsScreen(key: ValueKey('reports-$refreshVersion')),
        const SettingsScreen(),
      ];

  Future<void> openAddTransaction() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
      ),
    );

    if (!mounted) return;
    setState(() => refreshVersion++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[selectedIndex],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddTransaction,
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        elevation: 10,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Transaction',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.purple.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double todayCharges = 0;
  double monthlyCharges = 0;
  double todayCashIn = 0;
  double todayCashOut = 0;
  int todayTransactions = 0;
  List<Map<String, dynamic>> recentTransactions = [];

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    final transactions = await DatabaseHelper.getTransactions();
    final now = DateTime.now();

    double todayTotal = 0;
    double monthTotal = 0;
    double cashIn = 0;
    double cashOut = 0;
    int todayCount = 0;

    for (final transaction in transactions) {
      final date = DateTime.parse(transaction['date'] as String);
      final charge = (transaction['charge'] as num).toDouble();
      final amount = (transaction['amount'] as num).toDouble();

      if (date.year == now.year && date.month == now.month) {
        monthTotal += charge;
      }

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        todayTotal += charge;
        todayCount++;
        if (transaction['type'] == 'Cash In') {
          cashIn += amount;
        } else {
          cashOut += amount;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      todayCharges = todayTotal;
      monthlyCharges = monthTotal;
      todayCashIn = cashIn;
      todayCashOut = cashOut;
      todayTransactions = todayCount;
      recentTransactions = transactions.take(5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.purple, AppColors.blue],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cash Charge Tracker',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Track. Calculate. Grow.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.purple,
        backgroundColor: AppColors.surface,
        onRefresh: loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            GlowContainer(
              glow: true,
              gradient: const [
                Color(0xFF101B3A),
                Color(0xFF1B1039),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: AppColors.blue,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Today's Charges",
                        style: TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    peso(todayCharges),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$todayTransactions transaction${todayTransactions == 1 ? '' : 's'} today',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _BalanceMini(
                          label: 'Cash In',
                          value: peso(todayCashIn),
                          icon: Icons.arrow_downward,
                          color: AppColors.cyan,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BalanceMini(
                          label: 'Cash Out',
                          value: peso(todayCashOut),
                          icon: Icons.arrow_upward,
                          color: AppColors.pink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.calendar_month_outlined,
                    title: 'This Month',
                    value: compactPeso(monthlyCharges),
                    accent: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Transactions',
                    value: '$todayTransactions today',
                    accent: AppColors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            SectionTitle(
              title: 'Recent Transactions',
              subtitle: 'Your latest activity',
            ),
            const SizedBox(height: 12),
            if (recentTransactions.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'No transactions yet.',
              )
            else
              ...recentTransactions.map(
                (transaction) => TransactionCard(
                  transaction: transaction,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BalanceMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ADD TRANSACTION
// ============================================================

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final amountController = TextEditingController();
  final customerNameController = TextEditingController();
  final customerContactController = TextEditingController();

  String selectedType = 'Cash In';
  double? charge;
  bool calculating = false;
  bool submitted = false;
  int calcToken = 0;

  bool get customerInfoRequired {
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    return requiresCustomerInformation(selectedType, amount);
  }

  @override
  void initState() {
    super.initState();
    amountController.addListener(calculate);
  }

  Future<void> calculate() async {
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final token = ++calcToken;

    setState(() => calculating = true);
    final result = await DatabaseHelper.calculateCharge(amount);

    // Ignore outdated results if the amount changed while calculating.
    if (!mounted || token != calcToken) return;
    setState(() {
      charge = result;
      calculating = false;
    });
  }

  Future<void> saveTransaction() async {
    final amount = double.tryParse(amountController.text.trim());

    if (amount == null || amount <= 0) {
      _showMessage('Please enter a valid transaction amount.');
      return;
    }

    final calculatedCharge = await DatabaseHelper.calculateCharge(amount);
    if (!mounted) return;

    if (calculatedCharge == null) {
      _showMessage(
        'No charge rule covers this amount. Add or edit a rule in Settings.',
      );
      return;
    }

    // Customer information applies to Cash In of ₱5,000 and above only.
    final needsCustomer = requiresCustomerInformation(selectedType, amount);
    final customerName =
        needsCustomer ? customerNameController.text.trim() : null;
    final customerContact =
        needsCustomer ? customerContactController.text.trim() : null;

    if (needsCustomer) {
      setState(() => submitted = true);

      if ((customerName ?? '').isEmpty) {
        _showMessage('Please enter the customer name.');
        return;
      }

      final contactError = validatePhMobileNumber(customerContact ?? '');
      if (contactError != null) {
        _showMessage(contactError);
        return;
      }
    }

    await DatabaseHelper.insertTransaction({
      'type': selectedType,
      'amount': amount,
      'charge': calculatedCharge,
      'date': DateTime.now().toIso8601String(),
      'customerName': customerName,
      'customerContact': customerContact,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction saved successfully.'),
      ),
    );
    Navigator.pop(context);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    customerNameController.dispose();
    customerContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showCustomerInfo = customerInfoRequired;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text(
          'New Transaction',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          const Text(
            'Transaction Type',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  label: 'Cash In',
                  icon: Icons.arrow_downward,
                  selected: selectedType == 'Cash In',
                  color: AppColors.cyan,
                  onTap: () => setState(() => selectedType = 'Cash In'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TypeButton(
                  label: 'Cash Out',
                  icon: Icons.arrow_upward,
                  selected: selectedType == 'Cash Out',
                  color: AppColors.pink,
                  onTap: () => setState(() => selectedType = 'Cash Out'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Amount',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: moneyFormatters(),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            decoration: const InputDecoration(
              prefixText: '₱  ',
              prefixStyle: TextStyle(
                color: AppColors.purple,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
              hintText: 'Enter amount',
            ),
          ),
          const SizedBox(height: 16),
          GlowContainer(
            gradient: const [
              Color(0xFF111A35),
              Color(0xFF17102D),
            ],
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Service Charge',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        calculating
                            ? 'Calculating...'
                            : charge == null
                                ? '—'
                                : peso(charge!),
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.info_outline,
                  color: AppColors.dim,
                  size: 19,
                ),
              ],
            ),
          ),
          if (showCustomerInfo) ...[
            const SizedBox(height: 22),
            GlowContainer(
              color: const Color(0xFF171326),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user_outlined,
                          color: AppColors.pink),
                      SizedBox(width: 8),
                      Text(
                        'Customer Information',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Required for Cash In transactions of ₱5,000 and above.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: customerNameController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline),
                      labelText: 'Customer Name',
                      errorText: submitted &&
                              customerNameController.text.trim().isEmpty
                          ? 'Customer name is required.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customerContactController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_outlined),
                      labelText: 'Contact Number',
                      hintText: '09XXXXXXXXX',
                      helperText: 'Philippine mobile number: 11 digits, starts with 09',
                      errorText: submitted
                          ? validatePhMobileNumber(
                              customerContactController.text,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          NeonButton(
            label: 'Save Transaction',
            icon: Icons.check_rounded,
            onPressed: saveTransaction,
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    color,
                    AppColors.purple,
                  ],
                )
              : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? color : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HISTORY
// ============================================================

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Map<String, dynamic>> transactions = [];
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final data = await DatabaseHelper.getTransactions();
    if (!mounted) return;
    setState(() => transactions = data);
  }

  Future<void> deleteTransaction(int id) async {
    await DatabaseHelper.deleteTransaction(id);
    await loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = transactions.where((transaction) {
      if (filter == 'All') return true;
      return transaction['type'] == filter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transaction History',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: loadTransactions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: ['All', 'Cash In', 'Cash Out'].map((item) {
                  final selected = filter == item;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => filter = item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          gradient: selected
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.purple,
                                    AppColors.brightPurple,
                                  ],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          item,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.purple,
              onRefresh: loadTransactions,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                itemCount: filtered.isEmpty ? 1 : filtered.length,
                itemBuilder: (context, index) {
                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: 'No transactions found.',
                      ),
                    );
                  }

                  final transaction = filtered[index];
                  return TransactionCard(
                    transaction: transaction,
                    showDelete: true,
                    onDelete: () => _confirmDelete(transaction),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> transaction) async {
    final id = transaction['id'] as int;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete transaction?'),
        content: const Text(
          'This transaction will be permanently removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await deleteTransaction(id);
    }
  }
}

// ============================================================
// REPORTS
// ============================================================

String _monthName(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[month - 1];
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future<void> loadReports() async {
    final data = await DatabaseHelper.getTransactions();
    if (!mounted) return;
    setState(() => transactions = data);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    double monthlyCharges = 0;
    double monthlyCashIn = 0;
    double monthlyCashOut = 0;
    int monthlyCount = 0;
    int monthlyCashInCount = 0;
    int monthlyCashOutCount = 0;

    for (final transaction in transactions) {
      final date = DateTime.parse(transaction['date'] as String);
      if (date.year == now.year && date.month == now.month) {
        final amount = (transaction['amount'] as num).toDouble();
        final charge = (transaction['charge'] as num).toDouble();
        monthlyCharges += charge;
        monthlyCount++;
        if (transaction['type'] == 'Cash In') {
          monthlyCashIn += amount;
          monthlyCashInCount++;
        } else {
          monthlyCashOut += amount;
          monthlyCashOutCount++;
        }
      }
    }

    final net = monthlyCashIn - monthlyCashOut;
    final monthName = _monthName(now.month);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: loadReports,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.purple,
        onRefresh: loadReports,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            GlowContainer(
              gradient: const [
                Color(0xFF111B3B),
                Color(0xFF1B1237),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$monthName ${now.year}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    peso(monthlyCharges),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Total service charges this month',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.arrow_downward,
                    title: 'Cash In',
                    value: compactPeso(monthlyCashIn),
                    accent: AppColors.cyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    icon: Icons.arrow_upward,
                    title: 'Cash Out',
                    value: compactPeso(monthlyCashOut),
                    accent: AppColors.pink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            StatCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Net Cash Flow',
              value: compactPeso(net),
              accent: net >= 0 ? AppColors.green : AppColors.red,
            ),
            const SizedBox(height: 10),
            StatCard(
              icon: Icons.receipt_long_outlined,
              title: 'Transactions This Month',
              value: '$monthlyCount',
              accent: AppColors.blue,
            ),
            const SizedBox(height: 24),
            const SectionTitle(
              title: 'Monthly Overview',
              subtitle: 'A quick summary of your activity',
            ),
            const SizedBox(height: 12),
            GlowContainer(
              child: Column(
                children: [
                  _ReportRow(
                    label: 'Total money processed',
                    value: peso(monthlyCashIn + monthlyCashOut),
                  ),
                  _ReportRow(
                    label: 'Service charges earned',
                    value: peso(monthlyCharges),
                    valueColor: AppColors.purple,
                  ),
                  _ReportRow(
                    label: 'Cash In transactions',
                    value: '$monthlyCashInCount',
                  ),
                  _ReportRow(
                    label: 'Cash Out transactions',
                    value: '$monthlyCashOutCount',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ReportRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SETTINGS + EDITABLE CHARGE RULES
// ============================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> openPage(BuildContext context, Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const SectionTitle(
            title: 'Preferences',
            subtitle: 'Manage your app settings and information.',
          ),
          const SizedBox(height: 12),
          GlowContainer(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.tune_rounded,
                  iconColor: AppColors.purple,
                  title: 'Edit Charge Rules',
                  subtitle: 'Customize your service charges',
                  onTap: () => openPage(
                    context,
                    const ChargeRulesScreen(),
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.currency_exchange_rounded,
                  iconColor: AppColors.cyan,
                  title: 'Exchange Rates (API)',
                  subtitle: 'Fetch live currency rates from the internet',
                  onTap: () => openPage(
                    context,
                    const ExchangeRatesScreen(),
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.person_outline,
                  iconColor: AppColors.pink,
                  title: 'Customer Information',
                  subtitle: 'View customer information requirements',
                  onTap: () => openPage(
                    context,
                    const CustomerInformationScreen(),
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.wifi_off_rounded,
                  iconColor: AppColors.blue,
                  title: 'Offline Mode',
                  subtitle: 'Transactions are stored on this device',
                  onTap: () => openPage(
                    context,
                    const OfflineModeScreen(),
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.info_outline,
                  iconColor: AppColors.purple,
                  title: 'About the App',
                  subtitle: 'Cash Charge Tracker • Version 3.0.0',
                  onTap: () => openPage(
                    context,
                    const AboutAppScreen(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 7,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.20),
          ),
        ),
        child: Icon(icon, color: iconColor, size: 21),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
          ),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.dim,
      ),
      onTap: onTap,
    );
  }
}

// ============================================================
// CHARGE RULES SCREEN
// ============================================================

class ChargeRulesScreen extends StatefulWidget {
  const ChargeRulesScreen({super.key});

  @override
  State<ChargeRulesScreen> createState() => _ChargeRulesScreenState();
}

class _ChargeRulesScreenState extends State<ChargeRulesScreen> {
  List<Map<String, dynamic>> rules = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRules();
  }

  Future<void> loadRules() async {
    final data = await DatabaseHelper.getChargeRules();
    if (!mounted) return;
    setState(() {
      rules = data;
      loading = false;
    });
  }

  Future<void> editRule([Map<String, dynamic>? rule]) async {
    await showDialog(
      context: context,
      builder: (_) => ChargeRuleDialog(rule: rule),
    );
    await loadRules();
  }

  Future<void> deleteRule(Map<String, dynamic> rule) async {
    if (rules.length <= 1) {
      _showMessage('You must keep at least one charge rule.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete charge rule?'),
        content: Text(
          'Remove ${formatRange(rule)} = ${peso((rule['charge'] as num).toDouble())}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.deleteChargeRule(rule['id'] as int);
      await loadRules();
    }
  }

  Future<void> resetRules() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset charge rules?'),
        content: const Text(
          'This will restore the original Cash Charge Tracker rules.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.resetChargeRules();
      await loadRules();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Charge Rules',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const GlowContainer(
            gradient: [
              Color(0xFF111B3A),
              Color(0xFF1B1039),
            ],
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: AppColors.purple),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customize your charges',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Edit the amount ranges and service charges anytime.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionTitle(
            title: 'Charge Rules',
            subtitle: 'These apply to both Cash In and Cash Out.',
            trailing: IconButton(
              onPressed: () => editRule(),
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.purple,
              tooltip: 'Add rule',
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            )
          else
            GlowContainer(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final rule in rules) ...[
                    _EditableRuleTile(
                      rule: rule,
                      onEdit: () => editRule(rule),
                      onDelete: () => deleteRule(rule),
                    ),
                    if (rule != rules.last)
                      const Divider(height: 1),
                  ],
                  const SizedBox(height: 10),
                  _ContinuationInfo(rules: rules),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: resetRules,
            icon: const Icon(Icons.restore),
            label: const Text('Reset to Default Rules'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.muted,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CUSTOMER INFORMATION SCREEN
// ============================================================

class CustomerInformationScreen extends StatelessWidget {
  const CustomerInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customer Information',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const GlowContainer(
            gradient: [
              Color(0xFF171326),
              Color(0xFF111A35),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: AppColors.pink,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Current Requirement',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Text(
                  'Customer information is required only for Cash In transactions of ₱5,000 and above.',
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlowContainer(
            child: Column(
              children: [
                _RequirementRow(
                  icon: Icons.person_outline,
                  title: 'Customer Name',
                  subtitle: 'Required for Cash In ₱5,000 and above',
                ),
                const Divider(),
                _RequirementRow(
                  icon: Icons.phone_outlined,
                  title: 'Contact Number',
                  subtitle: 'Required and must use 09XXXXXXXXX format',
                ),
                const Divider(),
                const _RequirementRow(
                  icon: Icons.arrow_downward_rounded,
                  title: 'Cash Out',
                  subtitle: 'Customer information is not required',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _RequirementRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.purple.withValues(alpha: 0.12),
        child: Icon(icon, color: AppColors.purple),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// API INTEGRATION: EXCHANGE RATES
// ============================================================

class ExchangeRatesScreen extends StatefulWidget {
  const ExchangeRatesScreen({super.key});

  @override
  State<ExchangeRatesScreen> createState() => _ExchangeRatesScreenState();
}

class _ExchangeRatesScreenState extends State<ExchangeRatesScreen> {
  bool loading = false;
  String? errorMessage;
  String? lastUpdated;
  Map<String, dynamic> rates = {};

  // Open Exchange Rate API: PHP is the base currency.
  static final Uri _apiUri = Uri.parse(
    'https://open.er-api.com/v6/latest/PHP',
  );

  @override
  void initState() {
    super.initState();
    fetchRates();
  }

  Future<void> fetchRates() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(_apiUri).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw Exception('The server returned status ${response.statusCode}.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['result'] != 'success' ||
          decoded['rates'] is! Map<String, dynamic>) {
        throw Exception('The API returned an unexpected response.');
      }

      final rawRates = decoded['rates'] as Map<String, dynamic>;
      const currencies = ['USD', 'EUR', 'GBP', 'JPY', 'SGD', 'AUD', 'CAD', 'KRW'];
      final selectedRates = <String, dynamic>{};

      for (final currency in currencies) {
        if (rawRates[currency] is num) {
          selectedRates[currency] = rawRates[currency];
        }
      }

      if (selectedRates.isEmpty) {
        throw Exception('No currency rates were available.');
      }

      if (!mounted) return;
      setState(() {
        rates = selectedRates;
        lastUpdated = decoded['time_last_update_utc']?.toString();
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage =
            'Unable to load exchange rates. Check your internet connection and try again.';
        loading = false;
      });
    }
  }

  String _formatRate(dynamic value) {
    if (value is num) return value.toStringAsFixed(4);
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final currencies = rates.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Exchange Rates',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh rates',
            onPressed: loading ? null : fetchRates,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.purple,
        onRefresh: fetchRates,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            GlowContainer(
              gradient: const [
                Color(0xFF111B3A),
                Color(0xFF1B1039),
              ],
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.currency_exchange_rounded,
                    color: AppColors.cyan,
                    size: 30,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Live Currency Rates',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Rates are fetched from a public API. Values show how much of each currency is equivalent to ₱1 PHP.',
                    style: TextStyle(
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              const GlowContainer(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Fetching the latest rates...',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              )
            else if (errorMessage != null)
              GlowContainer(
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: AppColors.red,
                      size: 38,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: fetchRates,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                    ),
                    if (rates.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Previously loaded rates are still shown below.',
                        style: TextStyle(color: AppColors.dim, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            if (rates.isNotEmpty) ...[
              const SizedBox(height: 8),
              SectionTitle(
                title: 'Available Currencies',
                subtitle: 'Base currency: Philippine Peso (PHP)',
                trailing: const Icon(
                  Icons.public_rounded,
                  color: AppColors.cyan,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(currencies.length, (index) {
                final currency = currencies[index];
                final symbols = {
                  'USD': '\$',
                  'EUR': '€',
                  'GBP': '£',
                  'JPY': '¥',
                  'SGD': 'S\$',
                  'AUD': 'A\$',
                  'CAD': 'C\$',
                  'KRW': '₩',
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlowContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(
                            currency.substring(0, 2),
                            style: const TextStyle(
                              color: AppColors.cyan,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currency,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '1 PHP = ${symbols[currency] ?? ''}${_formatRate(rates[currency])}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.trending_up_rounded,
                          color: AppColors.cyan,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (lastUpdated != null) ...[
                const SizedBox(height: 8),
                Text(
                  'API last updated: $lastUpdated',
                  style: const TextStyle(
                    color: AppColors.dim,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
            if (!loading && errorMessage == null && rates.isEmpty)
              const EmptyState(
                icon: Icons.currency_exchange_rounded,
                message: 'No exchange-rate data is available yet. Pull down to refresh.',
              ),
            const SizedBox(height: 10),
            const Text(
              'Exchange rates are informational and may change. They do not affect your saved transactions or service-charge rules.',
              style: TextStyle(
                color: AppColors.dim,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// OFFLINE MODE SCREEN
// ============================================================

class OfflineModeScreen extends StatelessWidget {
  const OfflineModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Offline Mode',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const GlowContainer(
            gradient: [
              Color(0xFF101B3A),
              Color(0xFF111A35),
            ],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.blue,
                  size: 28,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Mode is Active',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Cash Charge Tracker works without an internet connection. Your transactions and charge rules are stored locally on this device.',
                        style: TextStyle(
                          color: AppColors.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ABOUT THE APP SCREEN
// ============================================================

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About the App',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          GlowContainer(
            glow: true,
            gradient: const [
              Color(0xFF111B3A),
              Color(0xFF1B1039),
            ],
            child: const Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.purple,
                  size: 54,
                ),
                SizedBox(height: 14),
                Text(
                  'Cash Charge Tracker',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Developer: Lovelyn D. Pojas\nVersion: 3.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String formatRange(Map<String, dynamic> rule) {
  final min = (rule['minAmount'] as num).toDouble();
  final max = (rule['maxAmount'] as num).toDouble();
  return '₱${formatAmount(min)} - ₱${formatAmount(max)}';
}

String formatAmount(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}

/// Shows how amounts ABOVE the highest saved rule are charged, using the
/// pattern derived from the saved rules, and warns about uncovered gaps.
class _ContinuationInfo extends StatelessWidget {
  final List<Map<String, dynamic>> rules;

  const _ContinuationInfo({required this.rules});

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) return const SizedBox.shrink();

    final sorted = ChargeEngine.sortRules(rules);
    final base = (sorted.last['maxAmount'] as num).toDouble();
    final preview = ChargeEngine.preview(rules, count: 4);
    final gaps = ChargeEngine.findGaps(rules);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 18,
                color: AppColors.purple,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Above ₱${formatAmount(base)}, the pattern of your last saved rules continues automatically. A rule you add yourself always takes priority.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final item in preview)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '₱${formatAmount(item['min']!)} - ₱${formatAmount(item['max']!)}  →  ${peso(item['charge']!)}',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final gap in gaps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'No rule covers ₱${formatAmount(gap[0])} - ₱${formatAmount(gap[1])}.',
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
class _EditableRuleTile extends StatelessWidget {
  final Map<String, dynamic> rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EditableRuleTile({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final charge = (rule['charge'] as num).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.purple,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatRange(rule),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Service charge: ${peso(charge)}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.blue,
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.red,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

class ChargeRuleDialog extends StatefulWidget {
  final Map<String, dynamic>? rule;

  const ChargeRuleDialog({
    super.key,
    this.rule,
  });

  @override
  State<ChargeRuleDialog> createState() => _ChargeRuleDialogState();
}

class _ChargeRuleDialogState extends State<ChargeRuleDialog> {
  late final TextEditingController minController;
  late final TextEditingController maxController;
  late final TextEditingController chargeController;
  String? error;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    minController = TextEditingController(
      text: rule == null
          ? ''
          : formatAmount((rule['minAmount'] as num).toDouble()),
    );
    maxController = TextEditingController(
      text: rule == null
          ? ''
          : formatAmount((rule['maxAmount'] as num).toDouble()),
    );
    chargeController = TextEditingController(
      text: rule == null
          ? ''
          : formatAmount((rule['charge'] as num).toDouble()),
    );
  }

  @override
  void dispose() {
    minController.dispose();
    maxController.dispose();
    chargeController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final min = double.tryParse(minController.text.trim());
    final max = double.tryParse(maxController.text.trim());
    final charge = double.tryParse(chargeController.text.trim());

    if (min == null || max == null || charge == null) {
      setState(() => error = 'Please enter valid numbers in all fields.');
      return;
    }

    if (min <= 0 || max <= 0) {
      setState(() => error = 'Minimum and maximum amounts must be greater than ₱0.');
      return;
    }

    if (charge <= 0) {
      setState(() => error = 'Service charge must be greater than ₱0.');
      return;
    }

    if (min > max) {
      setState(() => error = 'Minimum amount cannot be greater than maximum amount.');
      return;
    }

    final rules = await DatabaseHelper.getChargeRules();
    if (!mounted) return;
    final editingId = widget.rule?['id'] as int?;

    for (final existing in rules) {
      final existingId = existing['id'] as int;
      if (editingId != null && existingId == editingId) continue;

      final existingMin = (existing['minAmount'] as num).toDouble();
      final existingMax = (existing['maxAmount'] as num).toDouble();

      if (min == existingMin && max == existingMax) {
        setState(() {
          error = 'A rule for ${formatRange(existing)} already exists.';
        });
        return;
      }

      final overlaps = min <= existingMax && max >= existingMin;

      if (overlaps) {
        setState(() {
          error =
              'This range overlaps ${formatRange(existing)}. Use a different range.';
        });
        return;
      }
    }

    if (editingId == null) {
      await DatabaseHelper.insertChargeRule(
        minAmount: min,
        maxAmount: max,
        charge: charge,
      );
    } else {
      await DatabaseHelper.updateChargeRule(
        id: editingId,
        minAmount: min,
        maxAmount: max,
        charge: charge,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.rule != null;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(editing ? 'Edit Charge Rule' : 'Add Charge Rule'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyFormatters(),
              decoration: const InputDecoration(
                labelText: 'Minimum Amount',
                prefixText: '₱  ',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: maxController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyFormatters(),
              decoration: const InputDecoration(
                labelText: 'Maximum Amount',
                prefixText: '₱  ',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: chargeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyFormatters(),
              decoration: const InputDecoration(
                labelText: 'Service Charge',
                prefixText: '₱  ',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  error!,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: save,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return GlowContainer(
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.dim),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
