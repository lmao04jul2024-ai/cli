import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MerchantSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => 'Search Merchants';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black, // Matching DiscoveryScreen bottom nav
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white60),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white), // Search text color
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white60),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text("Find a place to earn stamps", 
            style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: ApiService.searchMerchants(query), // Assumes this exists in ApiService
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator(color: Color(0xFF007AFF))),
          );
        }

        final results = snapshot.data ?? [];

        return Container(
          color: Colors.black,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final merchant = results[index];
              return ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(merchant['coverImageUrl'] ?? ''),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(
                  merchant['businessName'] ?? '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  merchant['shortDescription'] ?? '',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF007AFF)),
                onTap: () => close(context, merchant),
              );
            },
          ),
        );
      },
    );
  }
}