import 'package:flutter/material.dart';
import '../models/property.dart';
import '../screens/landing/landing_page.dart';
import '../screens/landing/property_detail_page.dart';
import '../screens/landing/map_preview_page.dart';
import '../screens/auth/login_page.dart';
import '../screens/auth/register_page.dart';
import '../screens/landlord/dashboard.dart';
import '../screens/landlord/add_property.dart';

class AppRoutes {
  // Define constants once
  static const String landing = '/';
  static const String propertyDetail = '/detail';
  static const String mapPreview = '/map_preview'; // Only one definition
  static const String login = '/login';
  static const String register = '/register';
  static const String landlordDashboard = '/dashboard';
  static const String addProperty = '/add-property';

  // Define generateRoute once
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case landing:
        return MaterialPageRoute(builder: (_) => const LandingPage());

      case propertyDetail:
        final property = settings.arguments as Property;
        return MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property));

      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());

      case landlordDashboard:
        final landlordId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => LandlordDashboard(landlordId: landlordId));

      case addProperty:
        final landlordId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => AddPropertyPage(landlordId: landlordId));

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}