import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class MerchantInfoCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget child; // This will take the StampGrid or the Text info
  final VoidCallback? onMapTap;
  final String? businessName;
  final String? address;
  final String? phone;
  final String? hours;
  final double? rating;
  final VoidCallback? onInfoTap;
  final bool showMerchantDetails;

  const MerchantInfoCard({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.onMapTap,
    this.businessName,
    this.address,
    this.phone,
    this.hours,
    this.rating,
    this.onInfoTap,
    this.showMerchantDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Merchant info row
              if (businessName != null || rating != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
              if (businessName != null)
                      Expanded(
                        child: Text(
                          businessName!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ),
                          if (onInfoTap != null)
                            GestureDetector(
                              onTap: onInfoTap,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                   color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.info_outline,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (showMerchantDetails && businessName != null) const SizedBox(height: 8),
              // Address (shown only when showMerchantDetails is true)
              if (showMerchantDetails && address != null)
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: Colors.white54, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address!,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (showMerchantDetails && address != null) const SizedBox(height: 4),
              // Phone (shown only when showMerchantDetails is true)
              if (showMerchantDetails && phone != null)
                Row(
                  children: [
                    Icon(Icons.phone_outlined, color: Colors.white54, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      phone!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              if (showMerchantDetails && phone != null) const SizedBox(height: 4),
              // Hours (shown only when showMerchantDetails is true)
              if (showMerchantDetails && hours != null)
                Row(
                  children: [
                    Icon(Icons.access_time_outlined, color: Colors.white54, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      hours!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              if (showMerchantDetails && hours != null) const SizedBox(height: 8),
              // Rating (shown only when showMerchantDetails is true)
              if (showMerchantDetails && rating != null)
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              if (showMerchantDetails && rating != null) const SizedBox(height: 12),
              child,
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (onMapTap != null)
                    GestureDetector(
                      onTap: onMapTap,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                           color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.map_outlined,
                          color: Color.fromARGB(255, 123, 207, 123),
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
