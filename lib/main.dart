import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as path;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chrome/Web needs the SQLite Web factory before using sqflite.
  // Android/iOS will continue using the normal sqflite factory.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // Start database initialization immediately.
  DatabaseHelper.database;

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
  static List<Map<String, dynamic>>? _chargeRulesCache;

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
      // Web SQLite is persisted in the browser's IndexedDB.
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

  static Future<void> _insertDefaultRules(Database db) async {
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

  static Future<List<Map<String, dynamic>>> getChargeRules({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _chargeRulesCache != null) {
      return List<Map<String, dynamic>>.from(_chargeRulesCache!);
    }

    final db = await database;
    final data = await db.query(
      'charge_rules',
      orderBy: 'minAmount ASC',
    );

    _chargeRulesCache = List<Map<String, dynamic>>.from(data);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<int> insertChargeRule({
    required double minAmount,
    required double maxAmount,
    required double charge,
  }) async {
    final db = await database;
    final result = await db.insert('charge_rules', {
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      'charge': charge,
    });
    _chargeRulesCache = null;
    return result;
  }

  static Future<int> updateChargeRule({
    required int id,
    required double minAmount,
    required double maxAmount,
    required double charge,
  }) async {
    final db = await database;
    final result = await db.update(
      'charge_rules',
      {
        'minAmount': minAmount,
        'maxAmount': maxAmount,
        'charge': charge,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _chargeRulesCache = null;
    return result;
  }

  static Future<int> deleteChargeRule(int id) async {
    final db = await database;
    final result = await db.delete(
      'charge_rules',
      where: 'id = ?',
      whereArgs: [id],
    );
    _chargeRulesCache = null;
    return result;
  }

  static Future<void> resetChargeRules() async {
    final db = await database;
    await db.delete('charge_rules');
    await _insertDefaultRules(db);
    _chargeRulesCache = null;
  }

  static Future<double?> calculateCharge(double amount) async {
    if (amount <= 0) return 0;

    // Fixed charge rules. These are intentionally not editable.
    for (final rule in defaultRules) {
      final min = (rule['min'] as num).toDouble();
      final max = (rule['max'] as num).toDouble();
      final charge = (rule['charge'] as num).toDouble();

      if (amount >= min && amount <= max) {
        return charge;
      }
    }

    // Continue the same pattern for amounts above ₱5,000.
    final block = ((amount - 1001) / 1000).floor();
    final positionInBlock = amount - (1001 + (block * 1000));
    double charge = 15 + (block * 10);

    if (positionInBlock >= 100) {
      charge += 5;
    }

    return charge;
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

  final List<Widget> screens = const [
    HomeScreen(),
    TransactionsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  Future<void> openAddTransaction() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(),
      ),
    );

    setState(() {});
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

    setState(() => calculating = true);
    final result = await DatabaseHelper.calculateCharge(amount);

    if (!mounted) return;
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

    if (calculatedCharge == null) {
      _showMessage(
        'No charge rule covers this amount. Add or edit a rule in Settings.',
      );
      return;
    }

    if (requiresCustomerInformation(selectedType, amount)) {
      if (customerNameController.text.trim().isEmpty ||
          customerContactController.text.trim().isEmpty) {
        _showMessage(
          'Please enter the customer name and contact number.',
        );
        return;
      }
    }

    await DatabaseHelper.insertTransaction({
      'type': selectedType,
      'amount': amount,
      'charge': calculatedCharge,
      'date': DateTime.now().toIso8601String(),
      'customerName': requiresCustomerInformation(selectedType, amount)
          ? customerNameController.text.trim()
          : null,
      'customerContact': requiresCustomerInformation(selectedType, amount)
          ? customerContactController.text.trim()
          : null,
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
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline),
                      labelText: 'Customer Name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customerContactController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.phone_outlined),
                      labelText: 'Contact Number',
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
      body: RefreshIndicator(
        color: AppColors.purple,
        onRefresh: loadTransactions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Container(
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
                            color: selected
                                ? Colors.white
                                : AppColors.muted,
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
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'No transactions found.',
              )
            else
              ...filtered.map(
                (transaction) => TransactionCard(
                  transaction: transaction,
                  showDelete: true,
                  onDelete: () => _confirmDelete(transaction),
                ),
              ),
          ],
        ),
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

    for (final transaction in transactions) {
      final date = DateTime.parse(transaction['date'] as String);
      if (date.year == now.year && date.month == now.month) {
        final amount = (transaction['amount'] as num).toDouble();
        final charge = (transaction['charge'] as num).toDouble();
        monthlyCharges += charge;
        monthlyCount++;
        if (transaction['type'] == 'Cash In') {
          monthlyCashIn += amount;
        } else {
          monthlyCashOut += amount;
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
                    style: TextStyle(
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
                    value: '${transactions.where((t) => t['type'] == 'Cash In').where((t) {
                      final d = DateTime.parse(t['date'] as String);
                      return d.year == now.year && d.month == now.month;
                    }).length}',
                  ),
                  _ReportRow(
                    label: 'Cash Out transactions',
                    value: '${transactions.where((t) => t['type'] == 'Cash Out').where((t) {
                      final d = DateTime.parse(t['date'] as String);
                      return d.year == now.year && d.month == now.month;
                    }).length}',
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
// SETTINGS + FIXED CHARGE RULES
// ============================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          GlowContainer(
            gradient: const [
              Color(0xFF111B3A),
              Color(0xFF1B1039),
            ],
            child: const Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: AppColors.purple),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Charge Rules',
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'These are the fixed service charges used for Cash In and Cash Out.',
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
          const SizedBox(height: 12),
          GlowContainer(
            child: Column(
              children: [
                for (final rule in DatabaseHelper.defaultRules)
                  _FixedRuleTile(rule: rule),
                const Divider(height: 24),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: AppColors.purple,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'For amounts above ₱5,000, the same ₱5-step pattern continues automatically.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionTitle(
            title: 'Customer Information',
            subtitle: 'Only collected when required for a transaction.',
          ),
          const SizedBox(height: 12),
          GlowContainer(
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.person_outline,
                  color: AppColors.pink,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Customer Name and Contact Number are required only for Cash In transactions of ₱5,000 and above. Cash Out transactions do not require customer information.',
                    style: TextStyle(
                      color: AppColors.muted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlowContainer(
            child: const Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.wifi_off, color: AppColors.blue),
                  title: Text(
                    'Offline Mode',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Your transactions are stored on this device.',
                  ),
                ),
                Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline, color: AppColors.purple),
                  title: Text(
                    'About the App',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Cash Charge Tracker\nDark Cinematic Edition',
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

class _FixedRuleTile extends StatelessWidget {
  final Map<String, num> rule;

  const _FixedRuleTile({required this.rule});

  @override
  Widget build(BuildContext context) {
    final min = rule['min']!.toDouble();
    final max = rule['max']!.toDouble();
    final charge = rule['charge']!.toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
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
            child: Text(
              '₱${formatAmount(min)} - ₱${formatAmount(max)}',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '₱${formatAmount(charge)}',
            style: const TextStyle(
              color: AppColors.purple,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String formatAmount(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
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
