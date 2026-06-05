import 'package:flutter/material.dart';
import '../../models/property.dart';
import '../../routes/app_routes.dart';
import '../../services/property_service.dart';
import '../../services/sqlite_service.dart';
import '../../widgets/filter_chips.dart';
import '../../widgets/property_card.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final PropertyService _propertyService = PropertyService();
  final SqliteService _sqliteService = SqliteService();

  String selectedCategory = "All";
  String searchQuery = "";
  late Future<List<Property>> _propertiesFuture;

  @override
  void initState() {
    super.initState();
    _refreshPropertyList();
  }

  void _refreshPropertyList() {
    setState(() {
      _propertiesFuture = _getVerifiedProperties();
    });
  }

  Future<List<Property>> _getVerifiedProperties() async {
    try {
      final verifiedProperties = await _sqliteService.getVerifiedProperties();
      return verifiedProperties.map((map) => Property.fromMap(map)).toList();
    } catch (e) {
      print('Error fetching verified properties: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Accommodations',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshPropertyList(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by location or title...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (val) => setState(() => searchQuery = val),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Property Types',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                FilterChips(
                  categories: const ['All', 'Apartment', 'House', 'Bedsitter'],
                  selectedCategory: selectedCategory,
                  onSelected: (cat) => setState(() => selectedCategory = cat),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Available Listings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Property>>(
                  future: _propertiesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline,
                                  size: 48, color: Colors.red[400]),
                              const SizedBox(height: 12),
                              Text(
                                'Error loading properties: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _refreshPropertyList,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(Icons.home_work_outlined,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                "No verified rental listings available.\nCheck back later!",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final filteredProperties = snapshot.data!.where((p) {
                      final matchesType = selectedCategory == "All" ||
                          p.type == selectedCategory;
                      final matchesSearch =
                          p.location.toLowerCase().contains(searchQuery.toLowerCase()) ||
                              p.title.toLowerCase().contains(searchQuery.toLowerCase());
                      return matchesType && matchesSearch;
                    }).toList();

                    if (filteredProperties.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              Icon(Icons.search_off,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                "No properties match your filter selection.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredProperties.length,
                      itemBuilder: (context, index) {
                        return PropertyCard(property: filteredProperties[index]);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}