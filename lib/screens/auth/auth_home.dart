import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/neumorphic_card_wrapper.dart';
import '../../services/api_service.dart';

class AuthHome extends StatefulWidget {
  const AuthHome({super.key});

  @override
  State<AuthHome> createState() => _AuthHomeState();
}

class _AuthHomeState extends State<AuthHome> {
  bool _isLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FacebookAuth _facebookAuth = FacebookAuth.instance;
  final List<Map<String, dynamic>> _providers = [
    {
      'name': 'Google',
      'fontIcon': FontAwesomeIcons.google,
      'color': const Color(0xFFFF5722),
      'endpoint': '/api/auth/oauth/google',
    },
    {
      'name': 'Facebook',
      'fontIcon': FontAwesomeIcons.facebook,
      'color': const Color(0xFF1877F2),
      'endpoint': '/api/auth/oauth/facebook',
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingAuthAndRedirect();
  }

  Future<void> _checkExistingAuthAndRedirect() async {
    try {
      // First check if we have user_id in SharedPreferences (most reliable)
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final authToken = prefs.getString('auth_token');

      // If we have both user_id and auth_token, user is properly authenticated
      if (userId != null && userId.isNotEmpty && authToken != null && authToken.isNotEmpty) {
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, '/discovery');
        return;
      }

      // Otherwise, check Google Sign In
      try {
        final googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          // Verify we have user_id stored
          final userId = prefs.getString('user_id');
          if (userId != null && userId.isNotEmpty) {
            if (!context.mounted) return;
            Navigator.pushReplacementNamed(context, '/discovery');
            return;
          }
        }
      } catch (e) {
        debugPrint("Google sign-in check failed: $e");
      }

      // Check Facebook Auth
      try {
        final accessToken = await _facebookAuth.accessToken;
        if (accessToken != null) {
          // Verify we have user_id stored
          final userId = prefs.getString('user_id');
          if (userId != null && userId.isNotEmpty) {
            if (!context.mounted) return;
            Navigator.pushReplacementNamed(context, '/discovery');
            return;
          }
        }
      } catch (e) {
        print("Facebook auth check failed: $e");
      }

      // If we reach here, user is not properly authenticated
      debugPrint('[AUTH] No valid authentication found, staying on auth screen');
    } catch (e) {
      debugPrint("Error checking existing auth: $e");
    }
  }

  Future<void> _selectProvider(String endpoint) async {
    setState(() => _isLoading = true);

    try {
      if (endpoint.contains('google')) {
        await _signInWithGoogle();
      } else if (endpoint.contains('facebook')) {
        await _signInWithFacebook();
      }
    } catch (e) {
      if (!context.mounted) return;
      debugPrint("Error during provider auth: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication failed: ${e.toString()}')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User cancelled
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) throw Exception('No ID token received from Google');

      // Send to backend for verification and user creation/lookup
      final response = await ApiService.signInWithGoogleMobile(idToken);
      
      if (response == null) throw Exception('Backend authentication failed');

      // Store auth data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', idToken);
      await prefs.setString('user_id', response['userId'] ?? '');
      if (response['fullName'] != null) {
        await prefs.setString('full_name', response['fullName']);
      }
      if (response['email'] != null) {
        await prefs.setString('user_email', response['email']);
      }

      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/discovery');
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  Future<void> _signInWithFacebook() async {
    try {
      // Stop the auth_home spinner before showing phone dialog
      setState(() => _isLoading = false);

      // First, get phone number from user before Facebook auth
      final phoneNumber = await _getPhoneNumberFromUser();
      if (phoneNumber == null) {
        // User cancelled phone input
        return;
      }

      // Show spinner again while doing Facebook login
      if (mounted) setState(() => _isLoading = true);

      // Login without specifying behavior - will use web dialog if native app not available
      final loginResult = await _facebookAuth.login();
      if (loginResult.status != LoginStatus.success) {
        throw Exception('Facebook login failed: ${loginResult.message}');
      }

      final accessToken = loginResult.accessToken;
      if (accessToken == null) throw Exception('No access token from Facebook');

      // Send to backend for verification and user creation/lookup (with phone number)
      final response = await ApiService.signInWithFacebookMobile(
        accessToken.tokenString,
        phoneNumber: phoneNumber,
      );

      debugPrint("Facebook sign-in response from backend: $response");
      
      if (response == null) throw Exception('Backend authentication failed');

      // Store auth data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', accessToken.tokenString);
      await prefs.setString('user_id', response['userId'] ?? '');
      if (response['fullName'] != null) {
        await prefs.setString('full_name', response['fullName']);
      }
      if (response['email'] != null) {
        await prefs.setString('user_email', response['email']);
      }

      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/discovery');
    } catch (e) {
      throw Exception('Facebook sign-in failed: $e');
    }
  }

  Future<void> _testLogin() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.testLogin(userId: 'user_123');
      if (response == null) throw Exception('Test login returned null');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', response['userId'] ?? 'user_123');
      await prefs.setString('auth_token', 'test_token');
      if (response['fullName'] != null) {
        await prefs.setString('full_name', response['fullName']);
      }
      if (response['email'] != null) {
        await prefs.setString('user_email', response['email']);
      }

      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/discovery');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test login failed: ${e.toString()}')),
      );
      setState(() => _isLoading = false);
    }
  }

  // Show phone input dialog/screen and return the phone number
  Future<String?> _getPhoneNumberFromUser() async {
    String? phoneNumber;
    
    // Show dialog to get phone number
    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final phoneController = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2E),
          title: const Text(
            'Enter Phone Number',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Facebook doesn\'t provide phone numbers. Please enter your phone number to continue.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. +1 234 567 890',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFF007AFF)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF444444)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF007AFF)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final phone = phoneController.text.trim();
                if (phone.isNotEmpty) {
                  phoneNumber = phone;
                  Navigator.pop(context);
                }
              },
              child: const Text('Continue', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    return phoneNumber;
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    return InkWell(
      onTap: _isLoading ? null : () => _selectProvider(provider['endpoint']),
      child: NeumorphicCardWrapper(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: provider['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FaIcon(
                provider['fontIcon'],
                size: 16,
                color: provider['color'],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider['name']!,
                    style: const TextStyle(
                      color: Color.fromARGB(221, 255, 255, 255),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Continue with ${provider['name']}',
                    style: const TextStyle(
                      color: Color.fromARGB(221, 255, 255, 255),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Center(
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF007AFF)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Signing in...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo/Icon Section (kept from original auth_home.dart)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icons/logo_transparent.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title
                      const Text(
                        'Choose your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in with your preferred account',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                      const SizedBox(height: 48),

                      // Provider Selection (from auth_select_provider.dart)
                      Column(
                        children: _providers.map((provider) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildProviderCard(provider),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Test Login (development only)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white38,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isLoading ? null : _testLogin,
                          icon: const Icon(Icons.bug_report, size: 16),
                          label: const Text(
                            'TEST LOGIN (user_123)',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
