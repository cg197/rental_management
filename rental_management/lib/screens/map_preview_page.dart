import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/property.dart';

class MapPreviewPage extends StatelessWidget {
  final Property property;

  const MapPreviewPage({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final LatLng propertyLocation = LatLng(property.latitude, property.longitude);

    return Scaffold(
      appBar: AppBar(title: Text(property.title)),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: propertyLocation,
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('property_loc'),
            position: propertyLocation,
            infoWindow: InfoWindow(title: property.title),
          ),
        },
      ),
    );
  }
}