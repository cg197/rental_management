import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/property.dart';
import '../../routes/app_routes.dart';
import '../../services/property_service.dart'; // Ensure you import your service

class MapPreviewPage extends StatefulWidget {
  const MapPreviewPage({Key? super.key});

  @override
  State<MapPreviewPage> createState() => _MapPreviewPageState();
}

class _MapPreviewPageState extends State<MapPreviewPage> {
  final PropertyService _propertyService = PropertyService();
  late Future<List<Property>> _propertiesFuture;

  @override
  void initState() {
    super.initState();
    // Fetch real data from SQLite immediately
    _propertiesFuture = _propertyService.getAllProperties();
  }

  Set<Marker> _buildMarkers(List<Property> properties) {
    return properties.map((property) {
      return Marker(
        markerId: MarkerId('marker_${property.id}'),
        position: LatLng(property.latitude, property.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: property.title,
          snippet: 'ZK ${property.price.toStringAsFixed(0)}/mo - Tap to view',
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.propertyDetail, arguments: property);
          },
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explore Nearby')),
      body: FutureBuilder<List<Property>>(
        future: _propertiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final properties = snapshot.data ?? [];

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(-14.4431, 28.4463),
                  zoom: 13.0,
                ),
                markers: _buildMarkers(properties),
              ),
              // Your existing Floating Info Card here...
            ],
          );
        },
      ),
    );
  }
}