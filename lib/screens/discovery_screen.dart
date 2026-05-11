import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lal_mohar_user_app/widgets/user_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/engagement_column.dart';
import '../widgets/merchant_info.dart';
import '../screens/merchant_search_delegate.dart';
import '../widgets/stamp_grid.dart';
import '../services/api_service.dart';
import 'notification_screen.dart';

enum MerchantDisplayMode { defaultView, merchantDetails, stampGrid }

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  List<dynamic> _allDeals = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  int _currentStamps = 0;
  MerchantDisplayMode _displayMode = MerchantDisplayMode.defaultView;
  String? _customerId;
  StreamSubscription? _syncSubscription;
  late PageController _pageController;
  String _searchQuery = '';
  int _unreadCount = 0;
  Set<String> _redeemedDealIds = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    setState(() {
      _allDeals = [];
    });
    _searchQuery = '';
    _loadUserIdAndInitFeed();
  }

  Future<void> _loadUserIdAndInitFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/');
          }
        });
      }
      return;
    }

    setState(() {
      _customerId = userId;
    });

    _initFeed(userId).then((_) {
      if (mounted && _allDeals.isNotEmpty) {
        final firstMerchantId = _allDeals[_currentIndex]['id'];
        _startSync(firstMerchantId);
      } else if (mounted && _allDeals.isEmpty) {
        _showEmptyState();
      }
    });
    _refreshUnreadCount();
  }

  Future<void> _refreshUnreadCount() async {
    if (_customerId == null) return;
    final count = await ApiService.getUnreadCount(_customerId!);
    if (mounted) {
      setState(() => _unreadCount = count);
    }
  }

  void _showEmptyState() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _initFeed(String userId) async {
    final data = await ApiService.fetchDiscoveryFeed(userId);

    if (mounted) {
      setState(() {
        _allDeals = data;
        _isLoading = false;
      });
      if (data.isNotEmpty) {
        _updateMerchantState(0);
      }
    }
  }

  String get _currentCustomerId {
    if (_customerId == null) {
      throw Exception('Customer ID not loaded yet');
    }
    return _customerId!;
  }

  void _onPageChanged(int index) {
    _updateMerchantState(index);
  }

  Future<void> _updateMerchantState(int index) async {
    if (index >= _allDeals.length) return;

    final merchantId = _allDeals[index]['merchant']['id'];
    final currentDeal = _allDeals[index];

    setState(() {
      _currentIndex = index;
      _currentStamps = 0;
      _displayMode = MerchantDisplayMode.defaultView;
    });

    for (var deal in _allDeals) {
      final dealStatus = await ApiService.getDealStatus(
        merchantId,
        deal['id'] as String,
        _currentCustomerId,
      );
      if (dealStatus != null) {
        _allDeals[_allDeals.indexWhere((d) => d['id'] == deal['id'])] = {
          ...deal,
          'currentStamps': dealStatus['currentStamps'] ?? 0,
          'stampGoal': dealStatus['stampGoal'] ?? deal['minPurchases'] ?? 5,
          'isCompleted': dealStatus['isCompleted'] ?? false,
        };
      }
    }

    final cardStatus = await ApiService.getCardStatus(_currentCustomerId, merchantId);
    _currentStamps = cardStatus['currentStamps'] ?? 0;
    _startSync(merchantId);
  }

  void _startSync(String merchantId) {
    _syncSubscription?.cancel();
    if (_customerId == null) return;

    try {
      final channel = ApiService.connectToSync(_customerId!, merchantId);
      _syncSubscription = channel.stream.listen(
        (message) {
          if (!mounted) return;
          try {
            final data = jsonDecode(message.toString()) as Map<String, dynamic>;
            final type = data['type'] as String?;

            if (type == 'stamp') {
              final newStamps = data['currentStamps'] as int?;
              final dealRedemptions = data['dealRedemptions'] as List<dynamic>?;

              setState(() {
                if (newStamps != null) {
                  _currentStamps = newStamps;
                }
                // Update deal progress from WebSocket data
                if (dealRedemptions != null && dealRedemptions.isNotEmpty) {
                  for (final update in dealRedemptions) {
                    final dealId = update['dealId'] as String?;
                    if (dealId != null) {
                      final idx = _allDeals.indexWhere((d) => d['id'] == dealId);
                      if (idx != -1) {
                        _allDeals[idx] = {
                          ..._allDeals[idx],
                          'currentStamps': update['currentStamps'] ?? _allDeals[idx]['currentStamps'],
                          'stampGoal': update['stampGoal'] ?? _allDeals[idx]['stampGoal'],
                          'isCompleted': update['isCompleted'] ?? _allDeals[idx]['isCompleted'],
                        };
                      }
                    }
                  }
                } else if (newStamps != null && _allDeals.isNotEmpty) {
                  // No deal redemptions (no active deals) — update current deal's stamp display
                  // Use the card-level currentStamps so the stamp grid reflects the scan
                  final currentDeal = _allDeals[_currentIndex];
                  _allDeals[_currentIndex] = {
                    ...currentDeal,
                    'currentStamps': newStamps,
                    'stampGoal': currentDeal['stampGoal'] ?? currentDeal['minPurchases'] ?? 5,
                  };
                }
              });

              // Show stamp grid overlay briefly on stamp event
              if (_displayMode == MerchantDisplayMode.defaultView) {
                setState(() => _displayMode = MerchantDisplayMode.stampGrid);
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) setState(() => _displayMode = MerchantDisplayMode.defaultView);
                });
              }
            }
          } catch (e) {
            debugPrint('[WebSocket] Error parsing message: $e');
          }
        },
        onError: (error) {
          debugPrint('[WebSocket] Error: $error');
        },
        onDone: () {
          debugPrint('[WebSocket] Connection closed');
        },
      );
      debugPrint('[WebSocket] Connected to $merchantId');
    } catch (e) {
      debugPrint('[WebSocket] Failed to connect: $e');
    }
  }

  void _toggleStampGrid() {
    setState(() {
      if (_displayMode == MerchantDisplayMode.stampGrid) {
        _displayMode = MerchantDisplayMode.defaultView;
      } else {
        _displayMode = MerchantDisplayMode.stampGrid;
      }
    });
  }

  void _toggleMerchantDetails() {
    setState(() {
      if (_displayMode == MerchantDisplayMode.merchantDetails) {
        _displayMode = MerchantDisplayMode.defaultView;
      } else {
        _displayMode = MerchantDisplayMode.merchantDetails;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Loading merchants...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_allDeals.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.store_rounded,
                size: 80,
                color: Colors.white38,
              ),
              const SizedBox(height: 20),
              const Text(
                'No merchants available',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Check the server connection and try again later',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentDeal = _allDeals[_currentIndex];
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Background Image Layer
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: SizedBox.expand(
                key: ValueKey(currentDeal['id']),
                child: Image.network(
                  currentDeal['imageUrl']?? '',
                  cacheWidth: 1000,
                  key: ValueKey(currentDeal['id']),
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.3),
                  colorBlendMode: BlendMode.darken,
                  errorBuilder: (context, widget, error) {
                    debugPrint('[ERROR] Failed to load image: $error');
                    return Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Text(
                          'Image not available',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Vertical Swipe Feed
          PageView.builder(
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemCount: _allDeals.length,
            itemBuilder: (context, index) =>
                _buildOverlayContent(_allDeals[index]),
          ),

          // Side Actions
          Positioned(
            right: 12,
            bottom: 140,
            child: EngagementColumn(
              key: ValueKey(currentDeal['id']),
              merchant: currentDeal,
              isInfoMode: _displayMode == MerchantDisplayMode.stampGrid,
              onToggleAction: _toggleStampGrid,
              onLike: () => _handleLike(currentDeal),
              onRefer: () => _handleRefer(currentDeal),
              onShare: () => _handleShare(currentDeal),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildScannerButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildOverlayContent(dynamic deal) {
    final merchant = deal['merchant'] ?? {};
    final bool isCompleted = deal['isCompleted'] == true;
    final bool isRedeemed = _redeemedDealIds.contains(deal['id']);
    final bool showGiftIcon = isCompleted && !isRedeemed;

    // Determine what to show as child based on display mode
    Widget childContent;
    bool showMerchantDetails = false;

    switch (_displayMode) {
      case MerchantDisplayMode.defaultView:
        childContent = const SizedBox.shrink();
        showMerchantDetails = false;
        break;
      case MerchantDisplayMode.merchantDetails:
        childContent = const SizedBox.shrink();
        showMerchantDetails = true;
        break;
      case MerchantDisplayMode.stampGrid:
        childContent = StampGrid(
          total: deal['stampGoal'] ?? 5,
          currentStamps: deal['currentStamps'] ?? 0,
        );
        showMerchantDetails = false;
        break;
    }

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 15, bottom: 140, right: 80),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            MerchantInfoCard(
              key: ValueKey(_displayMode),
              title: deal['title'] ?? 'Unknown',
              description: deal['description'] ?? '',
              businessName: merchant['businessName'],
              address: merchant['address'],
              phone: merchant['phone'],
              hours: merchant['businessHours'],
              rating: merchant['rating']?.toDouble(),
              child: childContent,
              onMapTap: () => _handleMapTap(deal),
              onInfoTap: _toggleMerchantDetails,
              showMerchantDetails: showMerchantDetails,
            ),
            if (showGiftIcon)
              Positioned(
                top: -12,
                right: -12,
                child: GestureDetector(
                  onTap: () => _showRedeemPopup(deal, merchant),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF34C759).withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRedeemPopup(dynamic deal, dynamic merchant) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Gift icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.card_giftcard,
                color: Color(0xFF34C759),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You earned a reward!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              deal['title'] ?? '',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'at ${merchant['businessName'] ?? 'the merchant'}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Show QR Code button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _showQRScanner();
                },
                child: const Text(
                  'SHOW QR CODE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Show this QR code to the merchant to claim your reward',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showQRScanner() {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: UserQRCode(customerId: _currentCustomerId),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerButton() {
    return FloatingActionButton(
      onPressed: _showQRScanner,
      backgroundColor: Colors.white,
      shape: const CircleBorder(),
      child: const Icon(Icons.qr_code_scanner, color: Color(0xFF007AFF)),
    );
  }

  void _handleShare(dynamic deal) async {
    HapticFeedback.lightImpact();

    final merchant = deal['merchant'] ?? deal;
    final merchantId = merchant['id'];
    final businessName = merchant['businessName'] ?? 'this shop';
    final dealTitle = deal['title'] ?? 'great deal';
debugPrint('[Share] Generating referral - referrerId: $_currentCustomerId, merchantId: $merchantId');

final result = await ApiService.generateMerchantReferral(
  _currentCustomerId,
  merchantId,
);

debugPrint('[Share] Referral result: $result');


    if (result != null) {
      // Handle both response formats: {success: true, data: {...}} and {status: 200, data: {success: true, ...}}
      final responseData = result['data'] as Map<String, dynamic>?;
      final bool isSuccess = result['success'] == true || responseData?['success'] == true;

      if (isSuccess) {
        final String shareUrl = responseData?['shareUrl'] ?? '';
        final String merchantName = responseData?['merchantName'] ?? businessName;

        if (shareUrl.isNotEmpty) {
          await Share.share(
            'Check out $merchantName! They have a $dealTitle. Use my link to get a bonus stamp: $shareUrl',
            subject: '$merchantName - $dealTitle',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to generate share link - no URL returned")),
          );
        }
      } else {
        final message = responseData?['message'] ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Share failed: $message")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Share failed: No response from server")),
      );
    }
  }

  void _handleMapTap(dynamic merchant) async {
    final businessName = merchant['businessName'] ?? 'this shop';
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$businessName';

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(
        Uri.parse(googleMapsUrl),
        mode: LaunchMode.externalApplication,
      );
    } else {
      // Could not launch Google Maps
    }
  }

  void _handleLike(dynamic deal) async {
    final dealId = deal['id'];
    final bool wasLiked = deal['isLiked'] ?? false;
    final int previousCount = deal['likesCount'] ?? 0;

    debugPrint('[handleLike] dealId=$dealId, wasLiked=$wasLiked, prevCount=$previousCount');

    setState(() {
      deal['isLiked'] = !wasLiked;
      deal['likesCount'] = !wasLiked
          ? previousCount + 1
          : previousCount - 1;
    });

    HapticFeedback.mediumImpact();

    try {
      final response = await ApiService.toggleDealLike(_currentCustomerId, dealId);

      debugPrint('[handleLike] response=$response');

      if (response == null) {
        debugPrint('[handleLike] response is null, reverting');
        if (mounted) {
          setState(() {
            deal['isLiked'] = wasLiked;
            deal['likesCount'] = previousCount;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            deal['isLiked'] = response['isLiked'] ?? !wasLiked;
            deal['likesCount'] =
                response['likesCount'] ??
                (wasLiked ? previousCount - 1 : previousCount + 1);
          });
        }
      }
    } catch (e) {
      debugPrint('[handleLike] exception: $e');
      if (mounted) {
        setState(() {
          deal['isLiked'] = wasLiked;
          deal['likesCount'] = previousCount;
        });
      }
    }
  }

  void _handleRefer(dynamic deal) async {
    HapticFeedback.lightImpact();

    final result = await ApiService.getUserAppReferralCode(_currentCustomerId);
    
    if (result != null) {
      // Handle both response formats
      final responseData = result['data'] as Map<String, dynamic>?;
      final bool isSuccess = result['success'] == true || responseData?['success'] == true;

      if (isSuccess) {
        final String referralCode = responseData?['referralCode'] ?? '';

        if (referralCode.isNotEmpty) {
          await Share.share(
            'Join me on Lal Mohar! Use my referral code: $referralCode to get started.',
            subject: 'Join me on Lal Mohar!',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No referral code found")),
          );
        }
      } else {
        final message = responseData?['message'] ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Refer failed: $message")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to get referral code")),
      );
    }
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: Colors.black,
      height: 65,
      elevation: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBellIcon(),
          const SizedBox(width: 40),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final selectedMerchant = await showSearch(
                context: context,
                delegate: MerchantSearchDelegate(),
              );
              if (selectedMerchant != null) {
                _handleSearchSelection(selectedMerchant);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBellIcon() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    NotificationScreen(customerId: _currentCustomerId),
              ),
            ).then((_) => _refreshUnreadCount());
          },
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _handleSearchSelection(dynamic merchant) async {
    int existingIndex = _allDeals.indexWhere((m) => m['id'] == merchant['id']);

    if (existingIndex != -1) {
      _pageController.animateToPage(
        existingIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() {
        _allDeals.insert(_currentIndex + 1, merchant);
      });
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      final merchantId = _allDeals[_currentIndex + 1]['id'];
      final deals = await ApiService.fetchMerchantDeals(merchantId);
      if (deals.isNotEmpty && mounted) {
        for (var deal in deals) {
          await ApiService.getDealStatus(
            merchantId,
            deal['id'] as String,
            _currentCustomerId,
          );
        }
      }
    }
  }
}
