import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  // Load from environment variables (see lal_mohar_user_app/.env)
  // For Android emulator, use 10.0.2.2 to reach host's localhost
  // For iOS simulator, localhost works
  // For physical devices, use your machine's local network IP
  static String _getBaseUrl() {
    final envUrl = dotenv.env['BASE_API_URL'] ?? 'https://sastodeal-backend-git.onrender.com';
    // If running on Android and URL contains localhost, replace with 10.0.2.2
    if (Platform.isAndroid && envUrl.contains('localhost')) {
      return envUrl.replaceAll('localhost', '10.0.2.2');
    }
    return envUrl;
  }
  static String get baseUrl => _getBaseUrl();

  // Load from environment variables
  static String _getWsUrl() {
    final envUrl = dotenv.env['BASE_WS_URL'] ?? 'wss://sastodeal-backend-git.onrender.com/ws';
    // If running on Android and URL contains localhost, replace with 10.0.2.2
    if (Platform.isAndroid && envUrl.contains('localhost')) {
      return envUrl.replaceAll('localhost', '10.0.2.2');
    }
    return envUrl;
  }
  static String get wsUrl => _getWsUrl();

  /// 1. DISCOVERY FEED: Fetches merchants for the TikTok swipe UI
  static Future<List<dynamic>> fetchDiscoveryFeed(String userId) async {
    try {
      final client = http.Client();
      try {
        final response = await client.get(
          Uri.parse('$baseUrl/api/discovery/deals?userId=$userId'),
        );
        
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          return body['data'] ?? [];
        }
        return [];
      } finally {
        client.close();
      }
    } catch (e) {
      return [];
    }
  }

  /// 2. START CARD: Initializes a new loyalty card in the DB
  static Future<Map<String, dynamic>?> initializeCard(
    String customerId,
    String merchantId,
  ) async {
    try {
      final response = await http.Client().post(
        Uri.parse('$baseUrl/api/cards/initialize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'customerId': customerId, 'merchantId': merchantId}),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['data'];
      } else {
        throw Exception('Initialize card failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error initializing card: $e');
    }
  }

  /// 3. REAL-TIME SYNC: Manages the WebSocket for "Stamp Pops"
  static WebSocketChannel connectToSync(String customerId, String merchantId) {
    // Construct WebSocket URL carefully
    // wsUrl already contains the base URL with /ws path
    final uri = Uri.parse(wsUrl);
    
    // Determine correct port for WebSocket schemes
    // wss:// should use port 443 (standard for secure WebSocket)
    // ws:// should use port 80 (standard for non-secure WebSocket)
    int? portValue;
    if (uri.port != 0 && uri.port != null) {
      portValue = uri.port;
    } else {
      // Default ports for schemes
      if (uri.scheme == 'wss' || uri.scheme == 'https') {
        portValue = 443;
      } else if (uri.scheme == 'ws' || uri.scheme == 'http') {
        portValue = 80;
      }
      // If scheme unknown, portValue remains null
    }
    
    // Build the WebSocket URI properly to avoid :0 port
    final webSocketUri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: portValue, // null means use default port for scheme
      path: '${uri.path}/$customerId/$merchantId',
    );
    
    debugPrint('[WebSocket] Connecting to: $webSocketUri');
    return IOWebSocketChannel.connect(webSocketUri);
  }

  /// Fetch current card status for a specific merchant
  static Future<Map<String, dynamic>> getCardStatus(
    String customerId,
    String merchantId,
  ) async {
    try {
      final response = await http.Client().get(
        Uri.parse('$baseUrl/api/scan/$customerId/$merchantId'),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] as Map<String, dynamic>;
      } else {
        // Card not found — return default empty card
        return {'currentStamps': 0, 'totalResets': 0, 'carryoverStamps': 0};
      }
    } catch (e) {
      // Network error — return default empty card
      return {'currentStamps': 0, 'totalResets': 0, 'carryoverStamps': 0};
    }
  }

  /// Fetch merchant's active deals
  static Future<List<dynamic>> fetchMerchantDeals(
    String merchantId,
  ) async {
    try {
      final response = await http.Client().get(
        Uri.parse('$baseUrl/api/merchant/$merchantId/deals?isActive=true'),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] as List<dynamic>;
      } else {
        throw Exception('Error fetching deals: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching merchant deals: $e');
    }
  }

  /// Fetch ALL active deals from all merchants (new discovery feed)
  static Future<List<dynamic>> fetchDealsFeed(String userId) async {
    try {
      final response = await http.Client().get(
        Uri.parse('$baseUrl/api/discovery/deals?userId=$userId'),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] as List<dynamic>;
      } else {
        throw Exception('Error fetching deals feed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching deals feed: $e');
    }
  }

  /// Fetch deal status (deal-specific stamps) for customer at merchant
  static Future<Map<String, dynamic>?> getDealStatus(
    String merchantId,
    String dealId,
    String customerId,
  ) async {
    try {
      final response = await http.Client().get(
        Uri.parse('$baseUrl/api/merchant/$merchantId/deals/$dealId/status?customerId=$customerId'),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Handle DEAL LIKE toggling
  static Future<Map<String, dynamic>?> toggleDealLike(
    String userId,
    String dealId,
  ) async {
    try {
      final response = await http.Client().post(
        Uri.parse('$baseUrl/api/deal/$dealId/like'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      debugPrint('[toggleDealLike] status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] as Map<String, dynamic>?;
        if (data == null) {
          debugPrint('[toggleDealLike] data is null in response');
          return null;
        }
        return data;
      } else {
        debugPrint('[toggleDealLike] non-200 status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[toggleDealLike] exception: $e');
      throw Exception('Error toggling deal like: $e');
    }
    return null;
  }

  /// Handle Refer a friend
  static Future<Map<String, dynamic>?> generateMerchantReferral(
    String referrerId,
    String merchantId,
  ) async {
    try {
      final response = await http.Client().post(
        Uri.parse('$baseUrl/api/referrals/merchant'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'referrerId': referrerId,
          'merchantId': merchantId,
        }),
      );

      debugPrint('[API] generateMerchantReferral status: ${response.statusCode}');
      debugPrint('[API] generateMerchantReferral body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        debugPrint('[API] Referral generation failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[API] Error generating referral: $e');
      throw Exception('Error generating referral: $e');
    }
    return null;
  }

  /// Get user's app referral code for inviting friends
  static Future<Map<String, dynamic>?> getUserAppReferralCode(String userId) async {
    try {
      final response = await http.Client().get(
        Uri.parse('$baseUrl/api/referrals/user/$userId/referral-code'),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        // Return full body to handle both {success: true, data: {...}} and {status: N, data: {...}} formats
        return body;
      } else {
        return null;
      }
    } catch (e) {
      throw Exception('Error getting referral code: $e');
    }
  }

  /// Handle Search
  static Future<List<dynamic>> searchMerchants(String query) async {
    try {
      final response = await http.Client().get(
        Uri.parse('$baseUrl/api/merchant/search?query=$query'),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Test Login (development only) - login as any user by userId
  static Future<Map<String, dynamic>?> testLogin({required String userId}) async {
    try {
      final response = await http.Client().post(
        Uri.parse('$baseUrl/api/auth/test-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success']) {
          return body['data'] as Map<String, dynamic>;
        }
      }
      throw Exception('Test login failed: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error in test login: $e');
    }
  }

  /// MOBILE SDK AUTH: Google (send ID token to backend)
  static Future<Map<String, dynamic>?> signInWithGoogleMobile(String idToken, {String? referrerId, String? merchantId}) async {
    try {
      final body = <String, dynamic>{'idToken': idToken};
      if (referrerId != null) body['referrerId'] = referrerId;
      if (merchantId != null) body['merchantId'] = merchantId;
      
      final response = await http.Client().post(
        Uri.parse('$baseUrl/api/auth/mobile/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success']) {
          return body['data'] as Map<String, dynamic>;
        }
      }
      throw Exception('Google mobile auth failed: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error signing in with Google mobile: $e');
    }
  }

  /// NOTIFICATION METHODS

  /// Get user notifications
  static Future<List<dynamic>> getUserNotifications(String userId) async {
    try {
      final response = await http.Client().get(
        Uri.parse('$baseUrl/api/notifications/user/$userId'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Mark a single notification as read
  static Future<bool> markNotificationRead(String notificationId) async {
    try {
      final response = await http.Client().patch(
        Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Mark all notifications as read
  static Future<bool> markAllNotificationsRead(String userId) async {
    try {
      final response = await http.Client().patch(
        Uri.parse('$baseUrl/api/notifications/user/$userId/read-all'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadCount(String userId) async {
    try {
      final response = await http.Client().get(
        Uri.parse('$baseUrl/api/notifications/user/$userId/unread-count'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data']?['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// REDEEM METHODS

  /// Get deals that are ready for redemption (completed but not yet redeemed)
  static Future<List<dynamic>> getMyRedeemableDeals(String customerId) async {
    try {
      final response = await http.Client().get(
        Uri.parse('$baseUrl/api/deals/redeemable/$customerId'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Redeem a deal (customer shows QR, merchant scans to confirm)
  static Future<Map<String, dynamic>?> redeemDeal({
    required String dealId,
    required String customerId,
    String? cardId,
  }) async {
    try {
      final body = <String, dynamic>{'customerId': customerId};
      if (cardId != null) body['cardId'] = cardId;

      final response = await http.Client().post(
        Uri.parse('$baseUrl/api/deals/$dealId/redeem'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// MOBILE SDK AUTH: Facebook (send access token to backend)
  static Future<Map<String, dynamic>?> signInWithFacebookMobile(String accessToken, {String? phoneNumber, String? referrerId, String? merchantId}) async {
    try {
      final body = <String, dynamic>{'accessToken': accessToken};
      if (phoneNumber != null) {
        body['phoneNumber'] = phoneNumber;
      }
      if (referrerId != null) body['referrerId'] = referrerId;
      if (merchantId != null) body['merchantId'] = merchantId;
      
      final response = await http.Client().post(
        Uri.parse('$baseUrl/api/auth/mobile/facebook'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success']) {
          return body['data'] as Map<String, dynamic>;
        }
      }
      throw Exception('Facebook mobile auth failed: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error signing in with Facebook mobile: $e');
    }
  }
}
