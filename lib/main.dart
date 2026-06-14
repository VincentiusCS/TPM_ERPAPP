import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/employee_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/payroll_provider.dart';
import 'providers/sensor_provider.dart';
import 'routes/app_routes.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/employees_screen.dart';
import 'screens/employee_form_screen.dart';
import 'screens/shift_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/payroll_screen.dart';
import 'services/api_client.dart';
import 'services/attendance_service.dart';
import 'services/auth_service.dart';
import 'services/employee_service.dart';
import 'services/payroll_service.dart';
import 'services/biometric_service.dart';
import 'services/chatbot_service.dart';
import 'services/currency_service.dart';
import 'services/location_service.dart';
import 'services/shift_service.dart';
import 'screens/chatbot_screen.dart';
import 'screens/currency_screen.dart';
import 'screens/time_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/kesan_pesan_screen.dart';
import 'screens/quiz_screen.dart';
import 'services/push_notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initialize();

  final apiClient = ApiClient(navigatorKey: navigatorKey);
  final authService = AuthService(apiClient: apiClient);
  final employeeService = EmployeeService(apiClient: apiClient);
  final shiftService = ShiftService(apiClient: apiClient);
  final attendanceService = AttendanceService(apiClient: apiClient);
  final payrollService = PayrollService(apiClient: apiClient);
  final currencyService = CurrencyService(apiClient: apiClient);
  final chatbotService = ChatbotService(apiClient: apiClient);
  final biometricService = BiometricService();
  final locationService = LocationService();
  runApp(MainApp(
    authService: authService,
    employeeService: employeeService,
    shiftService: shiftService,
    attendanceService: attendanceService,
    payrollService: payrollService,
    currencyService: currencyService,
    chatbotService: chatbotService,
    biometricService: biometricService,
    locationService: locationService,
  ));
}

class MainApp extends StatelessWidget {
  final AuthService authService;
  final EmployeeService employeeService;
  final ShiftService shiftService;
  final AttendanceService attendanceService;
  final PayrollService payrollService;
  final CurrencyService currencyService;
  final ChatbotService chatbotService;
  final BiometricService biometricService;
  final LocationService locationService;

  const MainApp({
    super.key,
    required this.authService,
    required this.employeeService,
    required this.shiftService,
    required this.attendanceService,
    required this.payrollService,
    required this.currencyService,
    required this.chatbotService,
    required this.biometricService,
    required this.locationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authService: authService,
            biometricService: biometricService,
            locationService: locationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              EmployeeProvider(employeeService: employeeService),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              AttendanceProvider(attendanceService: attendanceService),
        ),
        ChangeNotifierProvider(
          create: (_) => PayrollProvider(payrollService: payrollService),
        ),
        ChangeNotifierProvider(
          create: (_) => SensorProvider(),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return _SensorLifecycleWrapper(
            child: MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'ERP Presensi & Payroll',
              theme: ThemeData(primarySwatch: Colors.indigo),
              initialRoute: authProvider.isAuthenticated
                  ? AppRoutes.dashboard
                  : AppRoutes.login,
              onGenerateRoute: (settings) =>
                  _generateRoute(settings, authProvider),
            ),
          );
        },
      ),
    );
  }

  /// Route guard: redirects to login if not authenticated and the
  /// requested route is not the login page itself.
  Route<dynamic>? _generateRoute(
    RouteSettings settings,
    AuthProvider authProvider,
  ) {
    // Map of route names to their widget builders
    final routeBuilders = <String, WidgetBuilder>{
      AppRoutes.login: (context) => const LoginScreen(),
      AppRoutes.dashboard: (context) => const DashboardScreen(),
      AppRoutes.employees: (context) => const EmployeesScreen(),
      AppRoutes.employeeForm: (context) => const EmployeeFormScreen(),
      AppRoutes.shifts: (context) => ShiftScreen(
            shiftService: shiftService,
            employeeService: employeeService,
          ),
      AppRoutes.attendance: (context) => AttendanceScreen(
            shiftService: shiftService,
          ),
      AppRoutes.payroll: (context) => const PayrollScreen(),
      AppRoutes.currency: (context) => CurrencyScreen(
            currencyService: currencyService,
          ),
      AppRoutes.time: (context) => const TimeScreen(),
      AppRoutes.chatbot: (context) => ChatbotScreen(
            chatbotService: chatbotService,
          ),
      AppRoutes.profile: (context) => const ProfileScreen(),
      AppRoutes.kesanPesan: (context) => const KesanPesanScreen(),
      AppRoutes.quiz: (context) => const QuizScreen(),
    };

    // Allow access to login without authentication
    if (settings.name == AppRoutes.login) {
      return MaterialPageRoute(
        builder: routeBuilders[AppRoutes.login]!,
        settings: settings,
      );
    }

    // Block access to all other routes if not authenticated → redirect to login
    if (!authProvider.isAuthenticated) {
      return MaterialPageRoute(
        builder: (context) => const LoginScreen(),
        settings: const RouteSettings(name: AppRoutes.login),
      );
    }

    // Role guard: block non-admin users from accessing staff management
    final user = authProvider.currentUser;
    final isAdminOnlyRoute = [
      AppRoutes.employees,
      AppRoutes.employeeForm,
    ].contains(settings.name);

    if (isAdminOnlyRoute && user?.role != 'admin') {
      return MaterialPageRoute(
        builder: (context) => const DashboardScreen(),
        settings: const RouteSettings(name: AppRoutes.dashboard),
      );
    }

    // Authenticated: resolve the requested route
    final builder = routeBuilders[settings.name];
    if (builder != null) {
      return MaterialPageRoute(
        builder: builder,
        settings: settings,
      );
    }

    // Unknown route: fallback to dashboard
    return MaterialPageRoute(
      builder: routeBuilders[AppRoutes.dashboard]!,
      settings: const RouteSettings(name: AppRoutes.dashboard),
    );
  }
}


/// A widget that manages the SensorProvider lifecycle based on app state.
///
/// - Starts the sensor listener when the app is in the foreground (resumed).
/// - Stops the sensor listener when the app goes to background (paused/inactive).
/// - Starts listening immediately on first build (app launch).
class _SensorLifecycleWrapper extends StatefulWidget {
  final Widget child;

  const _SensorLifecycleWrapper({required this.child});

  @override
  State<_SensorLifecycleWrapper> createState() =>
      _SensorLifecycleWrapperState();
}

class _SensorLifecycleWrapperState extends State<_SensorLifecycleWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start listening on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SensorProvider>().startListening();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sensorProvider = context.read<SensorProvider>();
    switch (state) {
      case AppLifecycleState.resumed:
        sensorProvider.startListening();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        sensorProvider.stopListening();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
