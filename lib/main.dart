import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/hive_data_store.dart';
import 'models/task.dart';
import 'services/task_notification_service.dart';
import 'utils/colors.dart';
import 'view/auth/auth_view.dart';
import 'view/home/home_view.dart';

const _supabaseUrl = String.fromEnvironment(
  'VITE_SUPABASE_URL',
  defaultValue: String.fromEnvironment('SUPABASE_URL', defaultValue: ''),
);
const _supabasePublishableKey = String.fromEnvironment(
  'VITE_SUPABASE_PUBLISHABLE_KEY',
  defaultValue: String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
  ),
);
const _isSupabaseConfigured =
    _supabaseUrl != '' && _supabasePublishableKey != '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter<Task>(TaskAdapter());
  await Hive.openBox<Task>(HiveDataStore.boxName);
  await Hive.openBox<String>(HiveDataStore.settingsBoxName);

  if (_isSupabaseConfigured) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
  }
  runTaskManager();
}

void runTaskManager({Future<void> Function()? startReminders}) {
  runApp(
    _isSupabaseConfigured || startReminders == null
        ? const MyApp()
        : BaseWidget(child: const MyApp()),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      if (startReminders != null) {
        await startReminders();
      } else {
        await TaskNotificationService.instance.initialize();
      }
    } catch (error, stackTrace) {
      debugPrint('Could not restore task reminders: $error\n$stackTrace');
    }
  });
}

class BaseWidget extends InheritedWidget {
  BaseWidget({super.key, HiveDataStore? dataStore, required super.child})
    : dataStore = dataStore ?? HiveDataStore();

  final HiveDataStore dataStore;

  static BaseWidget of(BuildContext context) {
    final base = context.dependOnInheritedWidgetOfExactType<BaseWidget>();
    if (base != null) {
      return base;
    }
    throw StateError('Could not find ancestor widget of type BaseWidget');
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final hasInjectedStore =
        context.getInheritedWidgetOfExactType<BaseWidget>() != null;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: MyColors.primary,
      surface: MyColors.surface,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: MyColors.canvas,
        appBarTheme: const AppBarTheme(
          backgroundColor: MyColors.canvas,
          foregroundColor: Color(0xFF202238),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF202238),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: MyColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: MyColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: MyColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: MyColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: MyColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: MyColors.primary, width: 1.5),
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            color: Color(0xFF202238),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            color: Color(0xFF202238),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: Color(0xFF202238),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(fontSize: 14, height: 1.4),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: MyColors.primary,
          foregroundColor: Colors.white,
          extendedPadding: EdgeInsets.symmetric(horizontal: 22),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ),
      home: !_isSupabaseConfigured
          ? hasInjectedStore
                ? const HomeView()
                : const _SupabaseConfigurationView()
          : const _AuthGate(),
    );
  }
}

class _SupabaseConfigurationView extends StatelessWidget {
  const _SupabaseConfigurationView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Configure VITE_SUPABASE_URL and '
            'VITE_SUPABASE_PUBLISHABLE_KEY using --dart-define '
            'to connect this app to Supabase.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late String? _userId;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    _userId = auth.currentUser?.id;
    _authSubscription = auth.onAuthStateChange.listen((state) {
      if (mounted) {
        setState(() => _userId = state.session?.user.id);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    if (userId == null) return const AuthView();
    return _AuthenticatedHome(key: ValueKey(userId), userId: userId);
  }
}

class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome({super.key, required this.userId});

  final String userId;

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}


class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late final HiveDataStore _dataStore;
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _dataStore = HiveDataStore(userId: widget.userId);
    _loadFuture = _loadTasks();
  }

  Future<void> _loadTasks() async {
    await _dataStore.initialize();
    await TaskNotificationService.instance.initialize();
    await TaskNotificationService.instance.syncTasks(
      _dataStore.box.values,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Print the real error in the terminal for debugging.
          debugPrint('Task loading error: ${snapshot.error}');
          debugPrint('Stack trace: ${snapshot.stackTrace}');

          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not load your tasks.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loadFuture = _loadTasks();
                        });
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return BaseWidget(
          dataStore: _dataStore,
          child: const HomeView(),
        );
      },
    );
  }
}
