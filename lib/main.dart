import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lal_mohar_user_app/screens/discovery_screen.dart';
import 'package:lal_mohar_user_app/screens/notification_screen.dart';
import './screens/auth/auth_home.dart';

Future<void> main() async {
  debugPrint('[APP] Starting stamp app initialization...');

  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  debugPrint('[APP] Splash preserved, starting app');

  // Load environment variables BEFORE accessing them
  await dotenv.load(fileName: ".env");
  debugPrint('[APP] Environment variables loaded');
  
  runApp(const StampApp());
}

class StampApp extends StatefulWidget {
  const StampApp({super.key});

  @override
  State<StampApp> createState() => _StampAppState();
}

class _StampAppState extends State<StampApp> {
  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stamp Rewards',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'SF Pro Display', // Minimalist SF Pro typography
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF), // Primary Blue accent
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      initialRoute: '/',
      routes: {
        '/discovery': (context) => const DiscoveryScreen(),
      },
      home: const AuthHome(),
    );
  }
}
