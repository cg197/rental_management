import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import '../../services/sqlite_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AdminDashboard extends StatefulWidget {
  final String adminId;
  const AdminDashboard({super.key, required this.adminId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final SqliteService _sqliteService = SqliteService();
  List<Map<String, dynamic>> _landlords = [];
  List<Map<String, dynamic>> _allProperties = [];
  Map<String, dynamic> _stats = {'landlords': 0, 'properties': 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  int _pendingRequestsCount() {
    return _landlords.where((u) => u['role'] == 'Landlord' && u['isApproved'] == 0).length;
  }

  int _verifiedPropertiesCount() {
    return _allProperties.where((p) => (p['isVerified'] ?? 0) == 1).length;
  }

  Future<void> _loadAdminData() async {
    final landlords = await _sqliteService.getAllLandlords();
    final stats = await _sqliteService.getSuperAdminStats();
    final props = await _sqliteService.getAllProperties();
    setState(() {
      _landlords = landlords;
      _stats = stats;
      _allProperties = props;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Portal"),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.dashboard), text: "Overview"),
            Tab(icon: Icon(Icons.home_work), text: "Properties"),
            Tab(icon: Icon(Icons.bar_chart), text: "Reports"),
            Tab(icon: Icon(Icons.question_answer_sharp), text: "Requests"),
            Tab(icon: Icon(Icons.manage_accounts), text: "Accounts"),
          ]),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            _buildOverviewTab(),
            _buildPropertyOverview(),
            _buildReportsTab(),
            _buildRequestsTab(),
            _buildAccountsTab()
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsTab() {
    return ListView.builder(
      itemCount: _landlords.length,
      itemBuilder: (context, i) {
        final user = _landlords[i];
        return ListTile(
          leading: CircleAvatar(child: Icon(user['role'] == 'Admin' ? Icons.admin_panel_settings : Icons.business)),
          title: Text(user['name']),
          subtitle: Text("${user['email']} • Role: ${user['role']}"),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteConfirm(user['id']),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirm(String userId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("Are you sure you want to delete this account? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _sqliteService.deleteUser(userId);
      _loadAdminData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account deleted successfully")),
      );
    }
  }

  Widget _buildRequestsTab() {
    final pendingLandlords = _landlords.where((u) => u['role'] == 'Landlord' && u['isApproved'] == 0).toList();

    if (pendingLandlords.isEmpty) {
      return const Center(child: Text("No pending registration requests."));
    }

    return ListView.builder(
      itemCount: pendingLandlords.length,
      itemBuilder: (context, i) {
        final user = pendingLandlords[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_add_alt)),
                title: Text(user['name']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['email']),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(user['phone'] ?? 'No phone number',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _sqliteService.toggleLandlordApproval(user['id'], true);
                          _loadAdminData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Registration approved'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          bool? confirm = await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Reject Request"),
                              content: const Text("Are you sure you want to reject this registration?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Reject")),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await _sqliteService.updateUserStatus(user['id'], 'Rejected');
                            _loadAdminData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Registration rejected'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab() => SingleChildScrollView(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _buildStatCard("Total Landlords", _stats['landlords'].toString()),
              _buildStatCard("Total Listings", _stats['properties'].toString()),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              _buildStatCard("Pending Requests", _pendingRequestsCount().toString()),
              _buildStatCard("Verified Listings", _verifiedPropertiesCount().toString()),
            ],
          ),
        ),
        const Divider(),
        const ListTile(
          title: Text("System Quick Actions", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text("Refresh Dashboard Data"),
          onTap: _loadAdminData,
        ),
      ],
    ),
  );

  Widget _buildPropertyOverview() => ListView.builder(
    itemCount: _allProperties.length,
    itemBuilder: (ctx, i) {
      final p = _allProperties[i];
      final isVerified = (p['isVerified'] ?? 0) == 1;
      final isRejected = (p['isVerified'] ?? 0) == -1;
      final isPending = (p['isVerified'] ?? 0) == 0;
      final isActive = (p['isActive'] ?? 1) == 1;

      Color cardColor = Colors.white;
      if (isRejected) cardColor = Colors.red[50]!;
      if (isPending) cardColor = Colors.orange[50]!;
      if (isVerified && !isActive) cardColor = Colors.grey[100]!;

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: cardColor,
        child: Column(
          children: [
            ListTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      p['title'] ?? 'No Title',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: (!isActive || isRejected) ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isVerified ? Colors.green : (isRejected ? Colors.red : Colors.orange),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isVerified ? 'Verified' : (isRejected ? 'Blocked' : 'Pending'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text("Landlord: ${p['landlordName'] ?? 'Unknown'}"),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(p['landlordPhone'] ?? 'No phone number',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Price: \$${p['price']}",
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (p['rejectionReason'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Reason: ${p['rejectionReason']}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Text("Verify:", style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Switch(
                          value: isVerified,
                          onChanged: (val) async {
                            bool? confirm = await showDialog(
                              context: ctx,
                              builder: (context) => AlertDialog(
                                title: Text(val ? "Verify Property" : "Block Property"),
                                content: Text(
                                  val
                                      ? "Are you sure you want to verify this property? It will become visible to tenants."
                                      : "Are you sure you want to block this property? This will hide it from tenants and flag it as potential scam.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text(val ? "Verify" : "Block"),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await _sqliteService.togglePropertyVerification(p['id'], val);
                              _loadAdminData();
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(val
                                      ? 'Property verified and activated'
                                      : 'Property blocked and deactivated'),
                                  backgroundColor: val ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (isVerified && !isRejected)
                    Expanded(
                      child: Row(
                        children: [
                          const Text("Active:", style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                          Switch(
                            value: isActive,
                            onChanged: (val) async {
                              await _sqliteService.togglePropertyActive(p['id'], val);
                              _loadAdminData();
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(val
                                      ? 'Property activated'
                                      : 'Property deactivated'),
                                  backgroundColor: val ? Colors.green : Colors.orange,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildReportsTab() => ListView(
    children: [
      ListTile(
        title: const Text("Export User Directory (Excel)"),
        leading: const Icon(Icons.file_download),
        onTap: _exportUserReport,
      ),
    ],
  );

  Widget _buildStatCard(String title, String value) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(title),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
        ]),
      ),
    ),
  );

  Future<void> _exportUserReport() async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Landlord_Properties'];

    sheet.appendRow([
      TextCellValue("User ID"),
      TextCellValue("Landlord Name"),
      TextCellValue("Property ID"),
      TextCellValue("Property Title")
    ]);

    List<Map<String, dynamic>> reportData = await _sqliteService.getDetailedLandlordReport();

    for (var row in reportData) {
      sheet.appendRow([
        TextCellValue(row['userId'].toString()),
        TextCellValue(row['landlordName'].toString()),
        TextCellValue(row['propertyId'].toString()),
        TextCellValue(row['propertyTitle'].toString())
      ]);
    }

    final directory = await getTemporaryDirectory();
    final filePath = "${directory.path}/Detailed_Report.xlsx";
    final file = File(filePath);

    List<int>? fileBytes = excel.save();
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);
      await Share.shareXFiles([XFile(filePath)], text: 'Here is your Landlord/Property Report');
    }
  }
}