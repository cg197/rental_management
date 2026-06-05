import 'package:flutter/cupertino.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class SqliteService {
  static final SqliteService _instance = SqliteService._internal();
  static Database? _database;

  SqliteService._internal();
  factory SqliteService() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rental_management.db');
    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 8) {
      var tableInfo = await db.rawQuery('PRAGMA table_info(properties)');
      bool hasIsVerified = tableInfo.any((column) => column['name'] == 'isVerified');
      bool hasIsActive = tableInfo.any((column) => column['name'] == 'isActive');
      bool hasRejectionReason = tableInfo.any((column) => column['name'] == 'rejectionReason');
      bool hasType = tableInfo.any((column) => column['name'] == 'type');

      if (!hasIsVerified) {
        await db.execute('ALTER TABLE properties ADD COLUMN isVerified INTEGER DEFAULT 0');
      }
      if (!hasIsActive) {
        await db.execute('ALTER TABLE properties ADD COLUMN isActive INTEGER DEFAULT 1');
      }
      if (!hasRejectionReason) {
        await db.execute('ALTER TABLE properties ADD COLUMN rejectionReason TEXT');
      }
      if (!hasType) {
        await db.execute('ALTER TABLE properties ADD COLUMN type TEXT');
      }

      var userTableInfo = await db.rawQuery('PRAGMA table_info(users)');
      bool hasIsApproved = userTableInfo.any((column) => column['name'] == 'isApproved');
      bool hasStatus = userTableInfo.any((column) => column['name'] == 'status');

      if (!hasIsApproved) {
        await db.execute('ALTER TABLE users ADD COLUMN isApproved INTEGER DEFAULT 0');
      }
      if (!hasStatus) {
        await db.execute('ALTER TABLE users ADD COLUMN status TEXT DEFAULT "Pending"');
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        password TEXT,
        role TEXT,
        phone TEXT,
        isApproved INTEGER DEFAULT 0,
        status TEXT DEFAULT 'Pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE properties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        description TEXT,
        type TEXT,
        status TEXT DEFAULT 'Available',
        price REAL,
        location TEXT,
        latitude REAL,
        longitude REAL,
        imagePaths TEXT,
        bedrooms INTEGER,
        bathrooms INTEGER,
        landlordId TEXT,
        isVerified INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 0,
        rejectionReason TEXT,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE bookings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        propertyId INTEGER NOT NULL,
        tenantId TEXT,
        viewerName TEXT,
        viewerContact TEXT,
        viewingDate TEXT,
        viewingTime TEXT,
        status TEXT DEFAULT 'Pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE work_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        propertyId INTEGER,
        title TEXT,
        description TEXT,
        status TEXT,
        priority TEXT,
        cost REAL,
        contractorName TEXT,
        photoPath TEXT,
        dateSubmitted TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        landlordId TEXT,
        tenantId TEXT,
        tenantName TEXT,
        propertyId INTEGER,
        propertyTitle TEXT,
        amount REAL,
        paymentDate TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE move_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        propertyId INTEGER,
        tenantId TEXT,
        moveType TEXT,
        date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tenant_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tenantId TEXT NOT NULL,
        propertyId INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'Pending',
        dateRequested TEXT NOT NULL,
        FOREIGN KEY(propertyId) REFERENCES properties(id)
      )
    ''');
  }

  // Authentication
  Future<Map<String, dynamic>?> authenticateUser(String email, String password) async {
    final db = await database;
    String hashedInput = _hashPassword(password);

    final List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, hashedInput],
    );

    return results.isNotEmpty ? results.first : null;
  }

  // User Management
  Future<bool> registerUser(String id, String name, String email, String phone, String password, String role) async {
    final db = await database;
    String hashedPassword = _hashPassword(password);
    try {
      await db.insert('users', {
        'id': id,
        'name': name,
        'email': email,
        'password': hashedPassword,
        'role': role,
        'phone': phone,
        'isApproved': role == 'Landlord' ? 0 : 1,
        'status': role == 'Landlord' ? 'Pending' : 'Active',
      });
      return true;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }

  String _hashPassword(String password) {
    return password.hashCode.toString();
  }

  // Landlord Methods
  Future<List<Map<String, dynamic>>> getPropertiesByLandlord(String landlordId) async {
    final db = await database;
    return await db.rawQuery('SELECT * FROM properties WHERE landlordId = ?', [landlordId]);
  }

  Future<List<Map<String, dynamic>>> getBookingsForLandlord(String landlordId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT b.*, p.title as propertyTitle 
      FROM bookings b 
      JOIN properties p ON b.propertyId = p.id 
      WHERE p.landlordId = ?
    ''', [landlordId]);
  }

  Future<int> deleteProperty(int id) async {
    final db = await database;
    return await db.delete('properties', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateBookingStatus(int bookingId, String status) async {
    final db = await database;
    return await db.update('bookings', {'status': status}, where: 'id = ?', whereArgs: [bookingId]);
  }

  Future<List<Map<String, dynamic>>> getWorkOrdersByLandlord(String landlordId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT w.*, p.title as propertyTitle 
      FROM work_orders w 
      JOIN properties p ON w.propertyId = p.id 
      WHERE p.landlordId = ?
    ''', [landlordId]);
  }

  // Tenant Methods
  Future<List<Map<String, dynamic>>> getPaymentsByTenant(String tenantId) async {
    final db = await database;
    return await db.query('payments', where: 'tenantId = ?', whereArgs: [tenantId.trim()]);
  }

  Future<List<Map<String, dynamic>>> getBookingsByTenant(String tenantId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT b.*, p.title AS propertyTitle 
      FROM bookings b
      JOIN properties p ON b.propertyId = p.id
      WHERE b.tenantId = ?
    ''', [tenantId]);
  }

  Future<int> addWorkOrder(Map<String, dynamic> workOrder) async {
    final db = await database;
    return await db.insert('work_orders', workOrder);
  }

  Future<int> addPayment(Map<String, dynamic> payment) async {
    final db = await database;
    return await db.insert('payments', payment);
  }

  Future<void> updatePayment(int id, double amount) async {
    final db = await database;
    await db.update('payments', {'amount': amount}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addTenantDocument(String tenantId, String filePath) async {
    final db = await database;
    await db.insert('move_records', {
      'tenantId': tenantId,
      'propertyId': null,
      'moveType': 'DocumentUpload',
      'date': DateTime.now().toIso8601String()
    });
    debugPrint("Saved document for tenant $tenantId at $filePath");
  }

  // Tenant Requests
  Future<int> createTenantRequest(String tenantId, int propertyId) async {
    final db = await database;
    return await db.insert('tenant_requests', {
      'tenantId': tenantId,
      'propertyId': propertyId,
      'status': 'Pending',
      'dateRequested': DateTime.now().toIso8601String(),
    });
  }

  Future<void> approveTenantRequest(int requestId) async {
    final db = await database;
    await db.update('tenant_requests', {'status': 'Approved'}, where: 'id = ?', whereArgs: [requestId]);
    await db.rawUpdate('''
      UPDATE properties 
      SET status = 'Occupied' 
      WHERE id = (SELECT propertyId FROM tenant_requests WHERE id = ?)
    ''', [requestId]);
  }

  Future<void> rejectTenantRequest(int requestId) async {
    final db = await database;
    await db.update('tenant_requests', {'status': 'Rejected'}, where: 'id = ?', whereArgs: [requestId]);
  }

  Future<List<Map<String, dynamic>>> getTenantProperties(String tenantId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.* FROM properties p
      INNER JOIN tenant_requests tr ON p.id = tr.propertyId
      WHERE tr.tenantId = ? AND tr.status = 'Approved'
    ''', [tenantId]);
  }

  Future<List<Map<String, dynamic>>> getPendingRequests(String landlordId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT tr.*, p.title 
      FROM tenant_requests tr
      INNER JOIN properties p ON tr.propertyId = p.id
      WHERE p.landlordId = ? AND tr.status = 'Pending'
    ''', [landlordId]);
  }

  Future<List<Map<String, dynamic>>> getTenantFinancialStatus(String landlordId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        p.tenantId, 
        p.tenantName, 
        p.propertyId, 
        p.propertyTitle, 
        SUM(p.amount) AS totalPaid, 
        COUNT(*) AS paymentsCount, 
        MAX(p.paymentDate) AS lastPaymentDate
      FROM payments p
      JOIN properties prop ON p.propertyId = prop.id
      WHERE prop.landlordId = ?
      GROUP BY p.tenantId, p.propertyId 
      ORDER BY lastPaymentDate DESC
    ''', [landlordId]);
  }

  // Admin Methods
  Future<List<Map<String, dynamic>>> getAllLandlords() async {
    final db = await database;
    return await db.query('users', where: 'role = ?', whereArgs: ['Landlord']);
  }

  Future<List<Map<String, dynamic>>> getLandlordsForApproval() async {
    final db = await database;
    return await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['Landlord'],
      columns: ['id', 'name', 'email', 'phone', 'role', 'isApproved', 'status'],
    );
  }

  Future<void> toggleLandlordApproval(String userId, bool isApproved) async {
    final db = await database;
    await db.update(
        'users',
        {
          'isApproved': isApproved ? 1 : 0,
          'status': isApproved ? 'Approved' : 'Rejected'
        },
        where: 'id = ?',
        whereArgs: [userId]
    );
  }

  Future<void> updateUserStatus(String userId, String status) async {
    final db = await database;
    await db.update(
      'users',
      {'status': status, 'isApproved': status == 'Rejected' ? -1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> deleteUser(String userId) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> deleteUserAndProperties(String userId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('properties', where: 'landlordId = ?', whereArgs: [userId]);
      await txn.delete('users', where: 'id = ?', whereArgs: [userId]);
    });
  }

  Future<Map<String, dynamic>> getSuperAdminStats() async {
    final db = await database;
    final landlords = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users WHERE role = "Landlord"')) ?? 0;
    final properties = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM properties')) ?? 0;
    final tenants = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users WHERE role = "Tenant"')) ?? 0;
    return {'landlords': landlords, 'properties': properties, 'tenants': tenants};
  }

  // Property Methods
  Future<List<Map<String, dynamic>>> getAllProperties() async {
    final db = await database;
    return await db.rawQuery('SELECT p.*, u.name as landlordName, u.phone as landlordPhone FROM properties p JOIN users u ON p.landlordId = u.id');
  }

  Future<List<Map<String, dynamic>>> getAllPropertiesForAdmin() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, u.name as landlordName, u.phone as landlordPhone,
        CASE 
          WHEN p.isVerified = 1 AND p.isActive = 1 THEN 'Active'
          WHEN p.isVerified = -1 THEN 'Rejected/Blocked'
          WHEN p.isVerified = 0 THEN 'Pending Verification'
          ELSE 'Inactive'
        END as status
      FROM properties p
      LEFT JOIN users u ON p.landlordId = u.id
      ORDER BY 
        CASE 
          WHEN p.isVerified = 0 THEN 1
          WHEN p.isVerified = 1 AND p.isActive = 1 THEN 2
          ELSE 3
        END
    ''');
  }

  Future<List<Map<String, dynamic>>> getVerifiedProperties() async {
    final db = await database;
    return await db.query('properties', where: 'isVerified = 1 AND isActive = 1');
  }

  Future<List<Map<String, dynamic>>> getActiveVerifiedProperties() async {
    final db = await database;
    return await db.query('properties', where: 'isVerified = 1 AND isActive = 1');
  }

  Future<List<Map<String, dynamic>>> getVisibleProperties() async {
    final db = await database;
    return await db.query('properties', where: 'isVerified = 1 AND isActive = 1');
  }

  // Property Verification
  Future<void> togglePropertyVerification(int propertyId, bool isVerified) async {
    final db = await database;
    final newStatus = isVerified ? 1 : -1;
    final isActive = isVerified ? 1 : 0;

    await db.update(
      'properties',
      {
        'isVerified': newStatus,
        'isActive': isActive,
        'rejectionReason': isVerified ? null : 'Property flagged as potential scam'
      },
      where: 'id = ?',
      whereArgs: [propertyId],
    );
  }

  Future<void> togglePropertyActive(int propertyId, bool isActive) async {
    final db = await database;
    await db.update(
      'properties',
      {'isActive': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [propertyId],
    );
  }

  // Additional helper methods
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final result = await db.query('users', where: 'email = ?', whereArgs: [email]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> updateUserPassword(String userId, String newPassword) async {
    final db = await database;
    await db.update(
      'users',
      {'password': _hashPassword(newPassword)},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<bool> updatePassword(String email, String newPassword) async {
    final db = await database;
    int count = await db.update(
      'users',
      {'password': _hashPassword(newPassword)},
      where: 'email = ?',
      whereArgs: [email],
    );
    return count > 0;
  }

  // FIXED: Changed from int to String
  Future<String?> getLandlordStatus(String landlordId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [landlordId],
    );
    if (result.isNotEmpty) {
      return result.first['status']?.toString();
    }
    return null;
  }

  // FIXED: Changed from int to String and removed duplicate
  Future<int> getRejectedPropertiesCount(String landlordId) async {
    final db = await database;
    final result = await db.query(
      'properties',
      where: 'landlordId = ? AND isVerified = -1',
      whereArgs: [landlordId],
    );
    return result.length;
  }

  Future<List<Map<String, dynamic>>> getDetailedLandlordReport() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        u.id AS userId, 
        u.name AS landlordName, 
        p.id AS propertyId, 
        p.title AS propertyTitle
      FROM users u
      LEFT JOIN properties p ON u.id = p.landlordId
      WHERE u.role = 'Landlord'
    ''');
  }
}