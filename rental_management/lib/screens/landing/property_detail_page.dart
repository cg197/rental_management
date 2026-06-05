import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/property.dart';
import '../../services/sqlite_service.dart';

class PropertyDetailPage extends StatefulWidget {
  final Property property;

  const PropertyDetailPage({Key? key, required this.property}) : super(key: key);

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final SqliteService _sqliteService = SqliteService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isBooking = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both a preferred date and time.')),
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final db = await _sqliteService.database;
      await db.insert('bookings', {
        'propertyId': widget.property.id,
        'viewerName': _nameController.text.trim(),
        'viewerContact': _contactController.text.trim(),
        'viewingDate': "${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}",
        'viewingTime': _selectedTime!.format(context),
        'status': 'Pending',
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Visit Requested!'),
            content: const Text('Your viewing schedule application has been logged.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return back to feed
                },
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    final prop = widget.property;
    final List<String> imageList = prop.imagePaths.isNotEmpty ? prop.imagePaths.split(',') : [];

    return Scaffold(
      appBar: AppBar(title: Text(prop.title)),
      body: SingleChildScrollView(

        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Image Carousel ---
            SizedBox(
              height: 220,
              width: double.infinity,
              child: imageList.isEmpty
                  ? Container(
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                child: const Center(child: Icon(Icons.holiday_village, size: 72, color: Colors.blueAccent)),
              )
                  : PageView.builder(
                itemCount: imageList.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(imageList[index]),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Text("Image not found")),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // --- Metrics & Info ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ZK ${prop.price.toStringAsFixed(0)}/mo', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                Chip(label: Text(prop.type, style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [

                const Icon(Icons.location_on, color: Colors.blueAccent, size: 18),
                const SizedBox(width: 4),
                Text(prop.location, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.king_bed, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Text('${prop.bedrooms} Bedrooms'),
                const SizedBox(width: 20),
                Icon(Icons.bathtub, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Text('${prop.bathrooms} Bathrooms'),
              ],
            ),
            const Divider(height: 32),
            const Text('Overview Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(prop.description, style: const TextStyle(fontSize: 15, height: 1.4)),
            const Divider(height: 32),

            // --- Booking Form ---
            const Text('Schedule an Inspection Visit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Your Full Name', prefixIcon: Icon(Icons.person)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please input your name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _contactController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Contact Phone / Email', prefixIcon: Icon(Icons.phone)),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your contact information' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month),
                              label: Text(_selectedDate == null ? 'Pick Date' : '${_selectedDate!.day}/${_selectedDate!.month}'),
                              onPressed: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time),
                              label: Text(_selectedTime == null ? 'Pick Time' : _selectedTime!.format(context)),
                              onPressed: _pickTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: _isBooking ? null : _submitBooking,
                        child: _isBooking ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Request', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}