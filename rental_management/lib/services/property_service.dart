import '../models/property.dart';
import 'sqlite_service.dart';

class PropertyService {
  final SqliteService _dbService = SqliteService();

  // Insert a new property entry
  Future<int> insertProperty(Property property) async {
    final db = await _dbService.database;
    return await db.insert(
      'properties',
      {
        'title': property.title,
        'description': property.description,
        'type': property.type,
        'price': property.price,
        'location': property.location,
        'latitude': property.latitude,
        'longitude': property.longitude,
        'imagePaths': property.imagePaths,
        'bedrooms': property.bedrooms,
        'bathrooms': property.bathrooms,
        'landlordId': property.landlordId,
      },
    );
  }

  // Unified secure delete method
  Future<bool> deleteProperty(int propertyId, String landlordId) async {
    final db = await _dbService.database;

    // Only delete if the propertyId matches AND it belongs to this specific landlord
    int count = await db.delete(
        'properties',
        where: 'id = ? AND landlordId = ?',
        whereArgs: [propertyId, landlordId]
    );

    return count > 0; // Returns true if a row was actually deleted
  }

  // Fetch all properties
  Future<List<Property>> getAllProperties() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('properties');

    return List.generate(maps.length, (i) {
      return Property(
        id: maps[i]['id'],
        title: maps[i]['title'],
        description: maps[i]['description'] ?? '',
        type: maps[i]['type'],
        price: maps[i]['price'],
        location: maps[i]['location'],
        latitude: maps[i]['latitude'],
        longitude: maps[i]['longitude'],
        imagePaths: maps[i]['imagePaths'] ?? '',
        bedrooms: maps[i]['bedrooms'],
        bathrooms: maps[i]['bathrooms'],
        landlordId: maps[i]['landlordId'],
      );
    });
  }
}