import 'package:flutter/material.dart';
import 'package:lal_mohar_user_app/screens/discovery_screen.dart';
import '../../widgets/neumorphic_card_wrapper.dart';

class AuthPhoneInput extends StatefulWidget {
  const AuthPhoneInput({super.key});

  @override
  State<AuthPhoneInput> createState() => _AuthPhoneInputState();
}

class _AuthPhoneInputState extends State<AuthPhoneInput> {
  final _formKey = GlobalKey<FormState>();
  String _phoneNumber = '';
  bool _isLoading = false;
  String? _error;

  // Example: Phone returned from OAuth (you'll get this from backend)
  String? _oauthPhoneNumber;

  @override
  void initState() {
    super.initState();
    // Pass the OAuth phone number if available
    _oauthPhoneNumber = null; // Will be passed from OAuth callback
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    if (!mounted) return;

    try {
      // Call backend to validate phone uniqueness and create account
      // await apiService.validateAndCreateMerchant(_phoneNumber);

      // If success, navigate to business setup
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DiscoveryScreen(),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Enter Phone Number',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Phone input card
                NeumorphicCardWrapper(
                  backgroundColor: const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.3),
                  padding: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),

                      const Text(
                        'We need your phone number',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This will be used to verify your account and link your business.',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone input field
                      TextFormField(
                        key: const Key('phoneInput'),
                        decoration: InputDecoration(
                          hintText: 'e.g. +1 234 567 890',
                          prefixIcon: const Icon(Icons.phone, color: Color(0xFF007AFF)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF444444)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF007AFF)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                        keyboardType: TextInputType.phone,
                        onChanged: (value) => setState(() => _phoneNumber = value),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          final cleaned = val.replaceAll(RegExp(r'[^0-9+]'), '');
                          if (cleaned.length < 10) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Note about OAuth phone
                      if (_oauthPhoneNumber != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'The phone from $_oauthPhoneNumber will be used if valid.',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Continue button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.phone_android, color: Colors.white),
                          label: Text(
                            _isLoading ? 'Validating...' : 'Continue',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _handleContinue,
                        ),
                      ),
                    ],
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
