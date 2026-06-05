class Property {
  final int? id;
  final String title;
  final String description;
  final String type;
  final double price;
  final String location;
  final double latitude;
  final double longitude;
  final String imagePaths;
  final int bedrooms;
  final int bathrooms;
  final String landlordId;
  final int? isVerified;  // Add this
  final int? isActive;    // Add this
  final String? createdAt; // Add this

  Property({
    this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.price,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.imagePaths,
    required this.bedrooms,
    required this.bathrooms,
    required this.landlordId,
    this.isVerified,
    this.isActive,
    this.createdAt,
  });

  // Add factory method to create Property from database Map
  factory Property.fromMap(Map<String, dynamic> map) {
    return Property(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: map['type'] ?? 'Apartment',
      price: (map['price'] ?? 0).toDouble(),
      location: map['location'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      imagePaths: map['imagePaths'] ?? '',
      bedrooms: map['bedrooms'] ?? 0,
      bathrooms: map['bathrooms'] ?? 0,
      landlordId: map['landlordId'] ?? '',
      isVerified: map['isVerified'] ?? 0,
      isActive: map['isActive'] ?? 0,
      createdAt: map['createdAt'],
    );
  }

  // Add method to convert Property to Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'price': price,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imagePaths': imagePaths,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'landlordId': landlordId,
      'isVerified': isVerified,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }
}