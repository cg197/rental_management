import 'package:flutter/material.dart';
import 'routes/app_routes.dart';

class PropertyManagerApp extends StatelessWidget {
  const PropertyManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rental Property Manager',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal, // change main color here
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),

      initialRoute: AppRoutes.landing,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}