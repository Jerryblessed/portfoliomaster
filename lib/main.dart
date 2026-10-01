import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:fl_chart/fl_chart.dart';

/**
 * PORTFOLIOMASTER - PRODUCTION APP
 * Features: Multi-Asset Portfolio Tracking, AI Risk Analysis, 
 * Real-time Price Updates, RevenueCat IAP, Smart Alerts
 */

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize RevenueCat
  await Purchases.configure(
    PurchasesConfiguration('goog_ufxBOyJiDyqkoODXulCSDsrkqiy'),
  );

  tz.initializeTimeZones();
  await _initNotifications();

  runApp(const PortfolioMasterApp());
}

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  await notificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );
}

class PortfolioMasterApp extends StatelessWidget {
  const PortfolioMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PortfolioMaster',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// === MODELS ===

enum UserTier { free, pro, premium }

enum AssetType { stock, crypto, gold, realEstate, fixedIncome, fund, other }

class UserSession {
  final String userId;
  final String email;
  int trialsRemaining;
  int analysisCredits;
  UserTier tier;
  bool alertsEnabled;

  UserSession({
    required this.userId,
    required this.email,
    this.trialsRemaining = 5,
    this.analysisCredits = 0,
    this.tier = UserTier.free,
    this.alertsEnabled = true,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    userId: json['user_id'] ?? '',
    email: json['email'] ?? '',
    trialsRemaining: json['trials_remaining'] ?? 5,
    analysisCredits: json['analysis_credits'] ?? 0,
    tier: UserTier.values.firstWhere(
      (t) => t.toString().split('.').last == (json['tier'] ?? 'free'),
      orElse: () => UserTier.free,
    ),
    alertsEnabled: json['alerts_enabled'] ?? true,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'email': email,
    'trials_remaining': trialsRemaining,
    'analysis_credits': analysisCredits,
    'tier': tier.toString().split('.').last,
    'alerts_enabled': alertsEnabled,
  };
}

class Investment {
  final String id;
  final String name;
  final AssetType type;
  final double quantity;
  final double purchasePrice;
  final double currentPrice;
  final String currency;
  final DateTime purchaseDate;
  final String? platform;
  final String? country;
  final String? sector;
  final DateTime? maturityDate;
  final String? notes;

  Investment({
    required this.id,
    required this.name,
    required this.type,
    required this.quantity,
    required this.purchasePrice,
    required this.currentPrice,
    this.currency = 'USD',
    required this.purchaseDate,
    this.platform,
    this.country,
    this.sector,
    this.maturityDate,
    this.notes,
  });

  double get totalValue => quantity * currentPrice;
  double get totalCost => quantity * purchasePrice;
  double get profitLoss => totalValue - totalCost;
  double get profitLossPercent =>
      totalCost > 0 ? ((profitLoss / totalCost) * 100) : 0;

  factory Investment.fromJson(Map<String, dynamic> json) => Investment(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    type: AssetType.values.firstWhere(
      (t) => t.toString().split('.').last == (json['type'] ?? 'other'),
      orElse: () => AssetType.other,
    ),
    quantity: (json['quantity'] ?? 0).toDouble(),
    purchasePrice: (json['purchase_price'] ?? 0).toDouble(),
    currentPrice: (json['current_price'] ?? 0).toDouble(),
    currency: json['currency'] ?? 'USD',
    purchaseDate: DateTime.parse(json['purchase_date']),
    platform: json['platform'],
    country: json['country'],
    sector: json['sector'],
    maturityDate:
        json['maturity_date'] != null
            ? DateTime.parse(json['maturity_date'])
            : null,
    notes: json['notes'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.toString().split('.').last,
    'quantity': quantity,
    'purchase_price': purchasePrice,
    'current_price': currentPrice,
    'currency': currency,
    'purchase_date': purchaseDate.toIso8601String(),
    'platform': platform,
    'country': country,
    'sector': sector,
    'maturity_date': maturityDate?.toIso8601String(),
    'notes': notes,
  };
}

class PortfolioAnalysis {
  final double totalValue;
  final double totalCost;
  final double totalProfitLoss;
  final Map<String, double> assetAllocation;
  final Map<String, double> countryExposure;
  final Map<String, double> sectorExposure;
  final String riskLevel;
  final List<String> recommendations;

  PortfolioAnalysis({
    required this.totalValue,
    required this.totalCost,
    required this.totalProfitLoss,
    required this.assetAllocation,
    required this.countryExposure,
    required this.sectorExposure,
    required this.riskLevel,
    required this.recommendations,
  });

  factory PortfolioAnalysis.fromJson(Map<String, dynamic> json) =>
      PortfolioAnalysis(
        totalValue: (json['total_value'] ?? 0).toDouble(),
        totalCost: (json['total_cost'] ?? 0).toDouble(),
        totalProfitLoss: (json['total_profit_loss'] ?? 0).toDouble(),
        assetAllocation: Map<String, double>.from(
          (json['asset_allocation'] ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v ?? 0).toDouble()),
          ),
        ),
        countryExposure: Map<String, double>.from(
          (json['country_exposure'] ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v ?? 0).toDouble()),
          ),
        ),
        sectorExposure: Map<String, double>.from(
          (json['sector_exposure'] ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v ?? 0).toDouble()),
          ),
        ),
        riskLevel: json['risk_level'] ?? 'Unknown',
        recommendations: List<String>.from(json['recommendations'] ?? []),
      );
}

// === API SERVICE ===

class ApiService {
  static const String baseUrl =
      'https://inve-dkb4dxbjhzd6d7g6.eastus-01.azurewebsites.net';

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );
    return jsonDecode(response.body);
  }

  static Future<List<Investment>> getInvestments(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/investments/$userId'),
    );
    final List<dynamic> data = jsonDecode(response.body)['investments'];
    return data.map((e) => Investment.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> addInvestment(
    String userId,
    Investment investment,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/investments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, ...investment.toJson()}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateInvestment(
    Investment investment,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/investments/${investment.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(investment.toJson()),
    );
    return jsonDecode(response.body);
  }

  static Future<void> deleteInvestment(String investmentId) async {
    await http.delete(Uri.parse('$baseUrl/api/investments/$investmentId'));
  }

  static Future<Map<String, dynamic>> updatePrices(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/update-prices'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    return jsonDecode(response.body);
  }

  static Future<PortfolioAnalysis> analyzePortfolio(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/analyze-portfolio'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    final data = jsonDecode(response.body);
    return PortfolioAnalysis.fromJson(data['analysis']);
  }

  static Future<Map<String, dynamic>> getAssetPrice(
    String assetName,
    String assetType,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/get-price'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'asset_name': assetName, 'asset_type': assetType}),
    );
    return jsonDecode(response.body);
  }
}

// === AUTH WRAPPER ===

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  UserSession? session;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_session');

    if (userData != null) {
      setState(() {
        session = UserSession.fromJson(jsonDecode(userData));
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  void handleAuth(UserSession user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_session', jsonEncode(user.toJson()));
    setState(() => session = user);

    // === SYNC WITH REVENUECAT ===
    try {
      await Purchases.logIn(user.userId);
      await Purchases.setEmail(user.email);

      // UPDATE THIS STRING FOR EACH APP:
      await Purchases.setAttributes({
        'app_name':
            'PortfolioMaster', // Change to 'MumWise', 'AICoach', 'PacksLight', etc.
        'signup_tier': user.tier.toString(),
      });
    } catch (e) {
      debugPrint('RevenueCat user sync error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return session == null
        ? LoginScreen(onSuccess: handleAuth)
        : MainNavigation(
          user: session!,
          onSessionUpdate: (u) => setState(() => session = u),
        );
  }
}

// === LOGIN SCREEN ===

class LoginScreen extends StatefulWidget {
  final Function(UserSession) onSuccess;
  const LoginScreen({super.key, required this.onSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  bool isLoading = false;
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final response =
          isLogin
              ? await ApiService.login(
                _emailController.text,
                _passController.text,
              )
              : await ApiService.register(
                _emailController.text,
                _passController.text,
              );

      if (response['success'] == true) {
        widget.onSuccess(UserSession.fromJson(response['user']));
      } else {
        _showError(response['message'] ?? 'Authentication failed');
      }
    } catch (e) {
      _showError('Network error. Please check your connection.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        final auth = await account.authentication;
        final response = await ApiService.loginWithGoogle(auth.idToken!);

        if (response['success'] == true) {
          widget.onSuccess(UserSession.fromJson(response['user']));
        }
      }
    } catch (e) {
      _showError('Google sign-in failed');
    }
  }

  void _showError(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade700, Colors.blue.shade400],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'PortfolioMaster',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Your AI Investment Companion',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 48),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator:
                          (v) => v!.contains('@') ? null : 'Invalid email',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator:
                          (v) => v!.length >= 6 ? null : 'Min 6 characters',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child:
                            isLoading
                                ? const CircularProgressIndicator()
                                : Text(
                                  isLogin ? 'Login' : 'Register',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin
                            ? 'New here? Create Account'
                            : 'Have an account? Login',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white54)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white54)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loginWithGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// === MAIN NAVIGATION ===

class MainNavigation extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onSessionUpdate;

  const MainNavigation({
    super.key,
    required this.user,
    required this.onSessionUpdate,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _updatePages();
  }

  @override
  void didUpdateWidget(MainNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _updatePages();
    }
  }

  void _updatePages() {
    _pages = [
      PortfolioScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
      InvestmentsScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
      AnalyticsScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
      UpgradeScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
      ProfileScreen(user: widget.user, onUpdate: widget.onSessionUpdate),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Investments',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium),
            label: 'Upgrade',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// === PORTFOLIO SCREEN ===

class PortfolioScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const PortfolioScreen({
    super.key,
    required this.user,
    required this.onUpdate,
  });

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<Investment> _investments = [];
  bool _isLoading = false;
  bool _isUpdatingPrices = false;
  double _totalValue = 0;
  double _totalCost = 0;

  @override
  void initState() {
    super.initState();
    _loadInvestments();
  }

  Future<void> _loadInvestments() async {
    setState(() => _isLoading = true);
    try {
      final investments = await ApiService.getInvestments(widget.user.userId);
      setState(() {
        _investments = investments;
        _calculateTotals();
      });
    } catch (e) {
      _showError('Failed to load investments');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateTotals() {
    _totalValue = _investments.fold(0, (sum, inv) => sum + inv.totalValue);
    _totalCost = _investments.fold(0, (sum, inv) => sum + inv.totalCost);
  }

  Future<void> _updatePrices() async {
    setState(() => _isUpdatingPrices = true);
    try {
      await ApiService.updatePrices(widget.user.userId);
      await _loadInvestments();
      _showSuccess('Prices updated successfully');
    } catch (e) {
      _showError('Failed to update prices');
    } finally {
      setState(() => _isUpdatingPrices = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profitLoss = _totalValue - _totalCost;
    final profitLossPercent =
        _totalCost > 0 ? (profitLoss / _totalCost * 100) : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Portfolio Overview',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _isUpdatingPrices ? null : _updatePrices,
            icon:
                _isUpdatingPrices
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh),
            tooltip: 'Update Prices',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInvestments,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: Colors.blue.shade700,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Portfolio Value',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${_totalValue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Profit/Loss',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${profitLoss.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color:
                                            profitLoss >= 0
                                                ? Colors.greenAccent
                                                : Colors.redAccent,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        profitLoss >= 0
                                            ? Colors.green.withOpacity(0.2)
                                            : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${profitLoss >= 0 ? '+' : ''}${profitLossPercent.toStringAsFixed(2)}%',
                                    style: TextStyle(
                                      color:
                                          profitLoss >= 0
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Asset Allocation',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAssetAllocationChart(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Investments',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to investments tab
                          },
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_investments.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No investments yet. Start adding!'),
                        ),
                      )
                    else
                      ..._investments
                          .take(5)
                          .map((inv) => _InvestmentCard(investment: inv)),
                  ],
                ),
      ),
    );
  }

  Widget _buildAssetAllocationChart() {
    final Map<AssetType, double> allocation = {};
    for (var inv in _investments) {
      allocation[inv.type] = (allocation[inv.type] ?? 0) + inv.totalValue;
    }

    if (allocation.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No data to display')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections:
                  allocation.entries.map((entry) {
                    final percent = (entry.value / _totalValue) * 100;
                    return PieChartSectionData(
                      value: entry.value,
                      title: '${percent.toStringAsFixed(1)}%',
                      color: _getColorForAssetType(entry.key),
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorForAssetType(AssetType type) {
    switch (type) {
      case AssetType.stock:
        return Colors.blue;
      case AssetType.crypto:
        return Colors.orange;
      case AssetType.gold:
        return Colors.amber;
      case AssetType.realEstate:
        return Colors.green;
      case AssetType.fixedIncome:
        return Colors.purple;
      case AssetType.fund:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

class _InvestmentCard extends StatelessWidget {
  final Investment investment;

  const _InvestmentCard({required this.investment});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getColorForAssetType(investment.type),
          child: Icon(
            _getIconForAssetType(investment.type),
            color: Colors.white,
          ),
        ),
        title: Text(
          investment.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${investment.quantity} @ \$${investment.currentPrice}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${investment.totalValue.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${investment.profitLoss >= 0 ? '+' : ''}${investment.profitLossPercent.toStringAsFixed(2)}%',
              style: TextStyle(
                color: investment.profitLoss >= 0 ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForAssetType(AssetType type) {
    switch (type) {
      case AssetType.stock:
        return Colors.blue;
      case AssetType.crypto:
        return Colors.orange;
      case AssetType.gold:
        return Colors.amber;
      case AssetType.realEstate:
        return Colors.green;
      case AssetType.fixedIncome:
        return Colors.purple;
      case AssetType.fund:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForAssetType(AssetType type) {
    switch (type) {
      case AssetType.stock:
        return Icons.show_chart;
      case AssetType.crypto:
        return Icons.currency_bitcoin;
      case AssetType.gold:
        return Icons.diamond;
      case AssetType.realEstate:
        return Icons.home;
      case AssetType.fixedIncome:
        return Icons.account_balance;
      case AssetType.fund:
        return Icons.pie_chart;
      default:
        return Icons.attach_money;
    }
  }
}

// === INVESTMENTS SCREEN ===

class InvestmentsScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const InvestmentsScreen({
    super.key,
    required this.user,
    required this.onUpdate,
  });

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  List<Investment> _investments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInvestments();
  }

  Future<void> _loadInvestments() async {
    setState(() => _isLoading = true);
    try {
      final investments = await ApiService.getInvestments(widget.user.userId);
      setState(() => _investments = investments);
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addInvestment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddInvestmentScreen(userId: widget.user.userId),
      ),
    );

    if (result == true) {
      _loadInvestments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Investments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _investments.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No investments yet',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text('Start tracking your portfolio'),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _addInvestment,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Investment'),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _investments.length,
                itemBuilder: (context, index) {
                  return _InvestmentCard(investment: _investments[index]);
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addInvestment,
        icon: const Icon(Icons.add),
        label: const Text('Add Investment'),
      ),
    );
  }
}

// === ADD INVESTMENT SCREEN ===

class AddInvestmentScreen extends StatefulWidget {
  final String userId;

  const AddInvestmentScreen({super.key, required this.userId});

  @override
  State<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends State<AddInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _currentPriceController = TextEditingController();
  final _platformController = TextEditingController();
  final _countryController = TextEditingController();
  final _sectorController = TextEditingController();
  final _notesController = TextEditingController();

  AssetType _selectedType = AssetType.stock;
  DateTime _purchaseDate = DateTime.now();
  DateTime? _maturityDate;
  bool _isLoading = false;
  bool _isFetchingPrice = false;

  Future<void> _fetchCurrentPrice() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isFetchingPrice = true);
    try {
      final response = await ApiService.getAssetPrice(
        _nameController.text,
        _selectedType.toString().split('.').last,
      );

      if (response['success'] == true && response['price'] != null) {
        setState(() {
          _currentPriceController.text = response['price'].toString();
        });
        _showSuccess('Price fetched successfully');
      } else {
        _showError('Could not fetch price. Please enter manually.');
      }
    } catch (e) {
      _showError('Error fetching price');
    } finally {
      setState(() => _isFetchingPrice = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final investment = Investment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      type: _selectedType,
      quantity: double.parse(_quantityController.text),
      purchasePrice: double.parse(_purchasePriceController.text),
      currentPrice: double.parse(_currentPriceController.text),
      purchaseDate: _purchaseDate,
      platform:
          _platformController.text.isEmpty ? null : _platformController.text,
      country: _countryController.text.isEmpty ? null : _countryController.text,
      sector: _sectorController.text.isEmpty ? null : _sectorController.text,
      maturityDate: _maturityDate,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    try {
      final response = await ApiService.addInvestment(
        widget.userId,
        investment,
      );

      if (response['success'] == true) {
        Navigator.pop(context, true);
      } else {
        _showError('Failed to add investment');
      }
    } catch (e) {
      _showError('Network error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Investment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<AssetType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Asset Type',
                border: OutlineInputBorder(),
              ),
              items:
                  AssetType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type.toString().split('.').last.toUpperCase(),
                      ),
                    );
                  }).toList(),
              onChanged: (value) => setState(() => _selectedType = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Asset Name',
                hintText: 'e.g., AAPL, Bitcoin, Gold',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: _isFetchingPrice ? null : _fetchCurrentPrice,
                  icon:
                      _isFetchingPrice
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.search),
                  tooltip: 'Fetch current price',
                ),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _purchasePriceController,
              decoration: const InputDecoration(
                labelText: 'Purchase Price per Unit',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentPriceController,
              decoration: const InputDecoration(
                labelText: 'Current Price per Unit',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Purchase Date'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_purchaseDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _purchaseDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _purchaseDate = date);
              },
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Optional Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _platformController,
              decoration: const InputDecoration(
                labelText: 'Platform/Broker',
                hintText: 'e.g., XTB, Renta Quattro',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Country',
                hintText: 'e.g., USA, Germany',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sectorController,
              decoration: const InputDecoration(
                labelText: 'Sector',
                hintText: 'e.g., Technology, Healthcare',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedType == AssetType.fixedIncome)
              ListTile(
                title: const Text('Maturity Date (Optional)'),
                subtitle: Text(
                  _maturityDate != null
                      ? DateFormat('MMM dd, yyyy').format(_maturityDate!)
                      : 'Not set',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) setState(() => _maturityDate = date);
                },
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child:
                  _isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                        'Add Investment',
                        style: TextStyle(fontSize: 16),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// === ANALYTICS SCREEN ===

class AnalyticsScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const AnalyticsScreen({
    super.key,
    required this.user,
    required this.onUpdate,
  });

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  PortfolioAnalysis? _analysis;
  bool _isAnalyzing = false;

  Future<void> _analyzePortfolio() async {
    if (widget.user.tier == UserTier.free && widget.user.trialsRemaining <= 0) {
      _showUpgradePrompt();
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final analysis = await ApiService.analyzePortfolio(widget.user.userId);

      if (widget.user.tier == UserTier.free) {
        widget.user.trialsRemaining--;
        widget.onUpdate(widget.user);
      }

      setState(() => _analysis = analysis);
    } catch (e) {
      _showError('Analysis failed. Please try again.');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _showUpgradePrompt() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Premium Feature'),
            content: const Text(
              'Portfolio analysis is a premium feature. Upgrade to Pro or Premium for unlimited access!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Upgrade'),
              ),
            ],
          ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body:
          _analysis == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.analytics, size: 80, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text(
                      'AI-Powered Portfolio Analysis',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Get insights on risk, diversification, and country/sector exposure',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_isAnalyzing)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton.icon(
                        onPressed: _analyzePortfolio,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(
                          widget.user.tier == UserTier.free
                              ? 'Analyze (${widget.user.trialsRemaining} trials left)'
                              : 'Analyze Portfolio',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.blue.shade700,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Risk Level',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _analysis!.riskLevel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Country Exposure',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._analysis!.countryExposure.entries.map(
                    (entry) => _ExposureBar(
                      label: entry.key,
                      percentage: entry.value,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sector Exposure',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._analysis!.sectorExposure.entries.map(
                    (entry) => _ExposureBar(
                      label: entry.key,
                      percentage: entry.value,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'AI Recommendations',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            _analysis!.recommendations
                                .map(
                                  (rec) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.lightbulb,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(rec)),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _analyzePortfolio,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Analysis'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _ExposureBar extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;

  const _ExposureBar({
    required this.label,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade200,
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

// === UPGRADE SCREEN (Keep as is from original) ===

class UpgradeScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const UpgradeScreen({super.key, required this.user, required this.onUpdate});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _isProcessing = false;

  Future<void> _purchaseSubscription(String productId) async {
    setState(() => _isProcessing = true);

    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        final package = offerings.current!.availablePackages.firstWhere(
          (p) => p.identifier == productId,
        );

        final purchaserInfo = await Purchases.purchasePackage(package);

        if (purchaserInfo.customerInfo.entitlements.all[productId]?.isActive ??
            false) {
          if (productId.contains('pro')) {
            widget.user.tier = UserTier.pro;
            widget.user.analysisCredits = 50;
          } else if (productId.contains('premium')) {
            widget.user.tier = UserTier.premium;
            widget.user.analysisCredits = -1; // Unlimited
          }

          widget.onUpdate(widget.user);
          _showSuccess('Subscription activated!');
        }
      }
    } catch (e) {
      _showError('Purchase failed: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _purchaseCredits(String productId, int credits) async {
    setState(() => _isProcessing = true);

    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        final package = offerings.current!.availablePackages.firstWhere(
          (p) => p.identifier == productId,
        );

        await Purchases.purchasePackage(package);

        widget.user.trialsRemaining += credits;
        widget.onUpdate(widget.user);
        _showSuccess('$credits credits added!');
      }
    } catch (e) {
      _showError('Purchase failed: ${e.toString()}');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade')),
      body:
          _isProcessing
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      size: 80,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unlock Premium Features',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get AI-powered insights and unlimited analysis',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stars, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Current: ${widget.user.tier.toString().split('.').last.toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Monthly Subscriptions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SubscriptionCard(
                      title: 'Pro Plan',
                      price: '\$25/month',
                      features: const [
                        '50 AI Analyses per month',
                        'Real-time price updates',
                        'Risk assessment',
                        'Priority support',
                      ],
                      color: Colors.blue,
                      onTap: () => _purchaseSubscription('pro'),
                    ),
                    const SizedBox(height: 16),
                    _SubscriptionCard(
                      title: 'Premium Plan',
                      price: '\$35/month',
                      features: const [
                        'Unlimited AI Analyses',
                        'Advanced diversification insights',
                        'Country & sector exposure',
                        'Custom alerts',
                        'Premium support',
                        'Early access to features',
                      ],
                      color: Colors.purple,
                      onTap: () => _purchaseSubscription('premium'),
                      recommended: true,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'One-Time Credit Packs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _CreditPackCard(
                      title: 'Investor Pack',
                      credits: 25,
                      price: '\$40',
                      onTap: () => _purchaseCredits('credits_25', 25),
                    ),
                    const SizedBox(height: 12),
                    _CreditPackCard(
                      title: 'Starter Pack',
                      credits: 10,
                      price: '\$15',
                      onTap: () => _purchaseCredits('credits_10', 10),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final String title;
  final String price;
  final List<String> features;
  final Color color;
  final VoidCallback onTap;
  final bool recommended;

  const _SubscriptionCard({
    required this.title,
    required this.price,
    required this.features,
    required this.color,
    required this.onTap,
    this.recommended = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Card(
          elevation: recommended ? 8 : 2,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            price,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_forward, color: color),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 20, color: color),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (recommended)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'RECOMMENDED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CreditPackCard extends StatelessWidget {
  final String title;
  final int credits;
  final String price;
  final VoidCallback onTap;

  const _CreditPackCard({
    required this.title,
    required this.credits,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.add_shopping_cart, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$credits Analysis Credits'),
        trailing: Text(
          price,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// === PROFILE SCREEN ===

class ProfileScreen extends StatefulWidget {
  final UserSession user;
  final Function(UserSession) onUpdate;

  const ProfileScreen({super.key, required this.user, required this.onUpdate});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 16),
          Text(
            widget.user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Center(
            child: Chip(
              label: Text(
                '${widget.user.tier.toString().split('.').last.toUpperCase()} TIER',
              ),
              backgroundColor: Colors.blue.shade100,
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Credits Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _CreditRow(
                    label: 'Trial Credits',
                    value: widget.user.trialsRemaining.toString(),
                  ),
                  _CreditRow(
                    label: 'Analysis Credits',
                    value:
                        widget.user.analysisCredits == -1
                            ? 'Unlimited'
                            : widget.user.analysisCredits.toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Price Update Alerts'),
            subtitle: const Text('Get notified of significant price changes'),
            value: widget.user.alertsEnabled,
            onChanged: (value) {
              setState(() => widget.user.alertsEnabled = value);
              widget.onUpdate(widget.user);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  final String label;
  final String value;

  const _CreditRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
