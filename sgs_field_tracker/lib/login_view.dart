import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tracker_state.dart';

class LoginView extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onEnterDemoMode;

  const LoginView({
    super.key,
    required this.onLoginSuccess,
    required this.onEnterDemoMode,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isWorkerOTP = false;
  final _otpController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<TrackerState>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C12),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E26),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2D2D38)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.track_changes, color: Colors.tealAccent, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'SGS FIELD TRACKER',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hands-Free GPS Attendance System',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 32),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Form Toggles (Username/Password vs OTP for Workers)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isWorkerOTP = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: !_isWorkerOTP ? Colors.tealAccent : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'CREDENTIALS',
                            style: TextStyle(
                              color: !_isWorkerOTP ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isWorkerOTP = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _isWorkerOTP ? Colors.tealAccent : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'WORKER OTP (SMS)',
                            style: TextStyle(
                              color: _isWorkerOTP ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (!_isWorkerOTP) ...[
                  // Username Field
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      prefixIcon: const Icon(Icons.person_outline, color: Colors.grey, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF13131A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF13131A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ] else ...[
                  // Phone Field & OTP request mock
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Phone Number (Emirates Access)',
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF13131A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      hintText: '+971 50 123 4567',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'OTP Code',
                      labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      prefixIcon: const Icon(Icons.security, color: Colors.grey, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF13131A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      hintText: 'Enter 6-digit code',
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Login Button
                ElevatedButton(
                  onPressed: () => _handleLogin(state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('AUTHENTICATE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
                const SizedBox(height: 20),

                // Separator
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFF2D2D38))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ),
                    Expanded(child: Divider(color: Color(0xFF2D2D38))),
                  ],
                ),
                const SizedBox(height: 20),

                // Bypass / Interactive Demo Screen button
                OutlinedButton.icon(
                  onPressed: widget.onEnterDemoMode,
                  icon: const Icon(Icons.developer_mode, size: 16),
                  label: const Text('BYPASS & ENTER DUAL SCREEN DEMO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.tealAccent,
                    side: const BorderSide(color: Colors.teal),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),

                // Helper Credentials list in card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13131A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LOGIN INFORMATION:', style: TextStyle(color: Colors.tealAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text('• Admin: admin / admin', style: TextStyle(color: Colors.grey, fontSize: 10)),
                      Text('• Other Roles & Workers: Created dynamically by the Admin', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin(TrackerState state) {
    setState(() => _errorMessage = null);

    if (_isWorkerOTP) {
      // Validate worker OTP mock (phone must be registered in state)
      final phone = _usernameController.text.trim();
      final otp = _otpController.text.trim();

      if (phone.isEmpty || otp.isEmpty) {
        setState(() => _errorMessage = 'Please enter phone number and OTP.');
        return;
      }

      final workerExists = state.workers.any((w) => w.phone == phone);
      if (workerExists && otp == '123456') {
        final worker = state.workers.firstWhere((w) => w.phone == phone);
        state.setSelectedWorker(worker.id);
        state.setActiveRole('Worker');
        widget.onLoginSuccess();
      } else {
        setState(() => _errorMessage = 'Invalid OTP. Enter 123456 for testing.');
      }
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both username and password.');
      return;
    }

    // Check default credentials
    if (username == 'admin' && password == 'admin') {
      state.setActiveRole('Admin');
      widget.onLoginSuccess();
      return;
    }

    // Check dynamically created users (Admin, Engineer, Supervisor) in database
    final matchedUsers = state.dbUsers.where((u) => u.username == username && u.password == password).toList();
    if (matchedUsers.isNotEmpty) {
      final user = matchedUsers.first;
      state.setActiveRole(user.role); // e.g. 'Admin', 'Engineer', 'Supervisor'
      widget.onLoginSuccess();
      return;
    }

    // Check dynamically created workers in database
    final matchedWorkers = state.workers.where((w) => w.username == username && w.password == password).toList();
    if (matchedWorkers.isNotEmpty) {
      final worker = matchedWorkers.first;
      state.setSelectedWorker(worker.id);
      state.setActiveRole('Worker');
      widget.onLoginSuccess();
      return;
    }

    setState(() => _errorMessage = 'Invalid username or password.');
  }
}
