import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import '../../services/sqlite_service.dart';
import '../../services/property_service.dart';
import '../../routes/app_routes.dart';

class LandlordDashboard extends StatefulWidget {
  final String landlordId;
  const LandlordDashboard({Key? key, required this.landlordId}) : super(key: key);

  @override
  State<LandlordDashboard> createState() => _LandlordDashboardState();
}

class _LandlordDashboardState extends State<LandlordDashboard> {
  final SqliteService _sqliteService = SqliteService();
  final PropertyService _propertyService = PropertyService();

  List<Map<String, dynamic>> _vacant = [];
  List<Map<String, dynamic>> _occupied = [];
  List<Map<String, dynamic>> _myBookings = [];
  List<Map<String, dynamic>> _ledger = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final allProps = await _sqliteService.getPropertiesByLandlord(widget.landlordId);
      final books = await _sqliteService.getBookingsForLandlord(widget.landlordId);
      final ledger = await _sqliteService.getTenantFinancialStatus(widget.landlordId);

      setState(() {
        _myBookings = books;
        _ledger = ledger;
        _vacant = allProps.where((p) => p['occupantName'] == null).toList();
        _occupied = allProps.where((p) => p['occupantName'] != null).toList();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isUnpaid(String? lastPaymentDate) {
    if (lastPaymentDate == null) return true;
    try {
      return DateTime.now().difference(DateTime.parse(lastPaymentDate)).inDays > 30;
    } catch (_) { return true; }
  }

  // --- ACTIONS ---
  Future<void> _deleteProperty(int propertyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Property"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _sqliteService.deleteProperty(propertyId);
      _loadDashboardData();
    }
  }

  void _changeStatus(int bookingId, String newStatus) async {
    await _sqliteService.updateBookingStatus(bookingId, newStatus);
    _loadDashboardData();
  }


  // --- EXPORT LOGIC ---
  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['RentLedger'];
    sheet.appendRow([TextCellValue("Tenant"), TextCellValue("Property"), TextCellValue("Last Payment"), TextCellValue("Status")]);
    for (var item in _ledger) {
      bool unpaid = _isUnpaid(item['lastPaymentDate']);
      sheet.appendRow([
        TextCellValue(item['tenantName'] ?? 'Unknown'),
        TextCellValue(item['propertyTitle'] ?? 'Unknown'),
        TextCellValue(item['lastPaymentDate']?.toString() ?? 'None'),
        TextCellValue(unpaid ? 'Unpaid' : 'Paid'),
      ]);
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/RentLedger.xlsx");
    await file.writeAsBytes(excel.encode()!);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
  }

  Future<void> _printLedger() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Table.fromTextArray(
            headers: [
              "Tenant",
              "Property",
              "Amount Paid",
              "Total Paid",
              "Last Payment",
              "Status"
            ],
            data: _ledger.map((item) {
              final unpaid = _isUnpaid(item['lastPaymentDate']);

              return [
                item['tenantName'] ?? 'Unknown',
                item['propertyTitle'] ?? 'Unknown',
                "ZK ${item['amount'] ?? 0}",        // 👈 single payment
                "ZK ${item['totalPaid'] ?? 0}",     // 👈 total per tenant
                item['lastPaymentDate'] ?? 'None',
                unpaid ? 'Unpaid' : 'Paid',
              ];
            }).toList(),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
  Future<void> _handleExportOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.table_chart), title: const Text("Export as Excel"), onTap: () { Navigator.pop(ctx); _exportToExcel(); }),
          ListTile(leading: const Icon(Icons.print), title: const Text("Print / Save as PDF"), onTap: () { Navigator.pop(ctx); _printLedger(); }),
        ],
      ),
    );
  }

  // --- BUILDERS ---
  Widget _buildPropertiesTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _buildSectionHeader("Vacant Units", Icons.home_outlined),
      ..._vacant.map((p) => _buildPropertyCard(p, false)),
      const SizedBox(height: 24),
      _buildSectionHeader("Occupied Units", Icons.lock_outline),
      ..._occupied.map((p) => _buildPropertyCard(p, true)),
    ],
  );

  Widget _buildPropertyCard(Map<String, dynamic> p, bool isOccupied) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: CircleAvatar(child: Icon(isOccupied ? Icons.person : Icons.home)),
      title: Text(p['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: isOccupied ? Text("Tenant: ${p['occupantName']}\nContact: ${p['occupantContact']}") : Text("ZK ${p['price']}/mo"),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOccupied)
            IconButton(icon: const Icon(Icons.payments, color: Colors.green),onPressed: () => _showAddPaymentDialog(
              p['id'],
              p['occupantName'],
            )),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteProperty(p['id'])),
        ],
      ),
      isThreeLine: isOccupied,
    ),
  );

  Widget _buildRequestsTab() => ListView.builder(
    padding: const EdgeInsets.all(8),
    itemCount: _myBookings.length,
    itemBuilder: (context, idx) {
      final b = _myBookings[idx];
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          title: Text(b['viewerName'], style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(b['propertyTitle']),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text("Contact: ${b['viewerContact']}"),
                const SizedBox(height: 10),
                if (b['status'] == 'Pending')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => _changeStatus(b['id'], 'Rejected'), child: const Text('Decline')),
                      ElevatedButton(onPressed: () => _changeStatus(b['id'], 'Approved'), child: const Text('Approve')),
                    ],
                  )
                else
                  Chip(label: Text(b['status'])),
              ]),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildFinancesTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Financial Records", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.download, color: Colors.blueAccent), onPressed: _handleExportOptions),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TOTAL COLLECTION",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "ZK ${_ledger.fold(0.0, (sum, item) {
                    final val = item['totalPaid'];
                    return sum + (val is num ? val : double.tryParse(val.toString()) ?? 0);
                  }).toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: _ledger.length,
          itemBuilder: (context, i) {
            final item = _ledger[i];
            bool unpaid = _isUnpaid(item['lastPaymentDate']);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                isThreeLine: true,
                title: Text(item['tenantName'] ?? 'Unknown', overflow: TextOverflow.ellipsis),
                subtitle: Text("Property: ${item['propertyTitle']}", overflow: TextOverflow.ellipsis),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "ZK ${item['totalPaid'] ?? 0}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isUnpaid(item['lastPaymentDate'])
                            ? Colors.red[100]
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _isUnpaid(item['lastPaymentDate']) ? "Unpaid" : "Paid",
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );



  Widget _buildSectionHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [Icon(icon, size: 20, color: Colors.blueAccent), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w600))]),
  );

  Widget _buildServiceTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _sqliteService.getWorkOrdersByLandlord(widget.landlordId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final orders = snapshot.data!;

        if (orders.isEmpty) {
          return const Center(
            child: Text("No maintenance requests"),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.build),
                title: Text(
                  order['title'] ?? 'Maintenance Request',
                ),
                subtitle: Text(
                  order['status'] ?? 'Pending',
                ),
              ),
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final int pendingCount =
        _myBookings.where((b) => b['status'] == 'Pending').length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Landlord Console',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(
          context,
          AppRoutes.addProperty,
          arguments: widget.landlordId,
        ).then((_) => _loadDashboardData()),
        label: const Text('Add Listing'),
        icon: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
        length: 4,
        child: Column(
          children: [
            if (pendingCount > 0)
              Container(
                width: double.infinity,
                color: Colors.orange.shade100,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "$pendingCount new booking request(s) waiting for approval",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),

                  ],
                ),
              ),
            TabBar(
              labelColor: Colors.blueAccent,
              tabs: [
                const Tab(text: "Properties"),
                Tab(text: "Requests${pendingCount > 0 ? ' ($pendingCount)' : ''}"),
                const Tab(text: "Finances"),
                const Tab(text: "Service"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPropertiesTab(),
                  _buildRequestsTab(),
                  _buildFinancesTab(),
                  _buildServiceTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _showAddPaymentDialog(
      int propertyId,
      String tenantName,
      ) async {
    final TextEditingController amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Record Rent Payment"),
        content: TextField(
          controller: amountController,
          decoration: const InputDecoration(labelText: "Amount (ZK)"),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _sqliteService.addPayment({
                'propertyId': propertyId,
                'tenantName': tenantName,
                'amount': double.parse(amountController.text),
                'paymentDate': DateTime.now().toIso8601String(),
              });

              Navigator.pop(ctx);
              _loadDashboardData();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}