import 'package:flutter/material.dart';
import '../../services/sqlite_service.dart';
import '../landlord/dashboard.dart';
import '../admin/admin_dashboard.dart';
import '../auth/register_page.dart';
import 'package:rental_management/screens/auth/forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final SqliteService _sqliteService = SqliteService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _sqliteService.authenticateUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (user != null) {
        // Check for approval status
        if (user['role'] == 'Landlord' && (user['isApproved'] == 0 || user['isApproved'] == null)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account pending admin approval,check within 24 hours'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          // Proceed to Navigation
          final String role = user['role'] ?? 'Admin';
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => role == 'Landlord'
                  ? LandlordDashboard(landlordId: user['id'])
                  : AdminDashboard(adminId: user['id'].toString()),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access Portal')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_person_outlined, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.key),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),

              // Inside LoginPage build() under the Sign In button
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>  ForgotPasswordPage()),
                  );
                },
                child: const Text("Forgot Password?"),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleLogin,
                child: const Text('Sign In'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterPage()),
                  );
                },
                child: const Text("Don't have an account? Sign up here"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}