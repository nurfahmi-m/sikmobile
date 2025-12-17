import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_page.dart';
import 'registration_page.dart';
import 'utils/device_helper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistem Absensi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Roboto',
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nipController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // URL API
  final String apiUrl = 'http://10.5.3.49/siak/public/api/login';

  @override
  void dispose() {
    _nipController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    final deviceId = await DeviceHelper.getDeviceId();

    if (deviceId.isEmpty) {
      _showError('Gagal mendapatkan Device ID');
      return;
    }

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': _nipController.text.trim(),
        'password': _passwordController.text,
        'device_id': deviceId,
      }),
    );

    final json = jsonDecode(response.body);

    if (response.statusCode == 200 && json['success'] == true) {
      final data = json['data'] ?? {};

      // // ================= NULL SAFE =================
      // final String namaLengkap =
      //     data['nama_lengkap'] ??
      //     data['username'] ??
      //     'Pengguna';

      // final String satker =
      //     data['nama_jurusan'] ??
      //     data['satker'] ??
      //     'Satuan Kerja Tidak Diketahui';

      // final String nip = _nipController.text.trim();
      // =============================================

      // Simpan ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_token', data['api_token'] ?? '');
      await prefs.setString('id_user', data['id_user']?.toString() ?? '');
      await prefs.setString('username', data['username'] ?? '');
      await prefs.setString('id_peg', data['id_peg']?.toString() ?? '');

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(
            nama: data['nama_peg'] as String,
            nip: data['nip'] as String,
            satker: data['nama_jurusan'] as String,
            fotoUrl: data['foto_url'], // boleh null
          ),
        ),
      );

    } else {
      _showError(json['message'] ?? 'Login gagal');
    }
  } catch (e) {
    _showError('Terjadi kesalahan: $e');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}


  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegistrationPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF40C89D),
              const Color(0xFF40C89D),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // HEADER SECTION
                  Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/poltek.jpg'),
                          fit: BoxFit.cover,
                          opacity: 0.20,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // CONTENT DENGAN PADDING
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: 290,
                                  height: 70,
                                  child: Image.asset(
                                    'assets/images/kmnks-dark.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                const Text(
                                  'SIK Mobile',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D8A47),
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),

                                const Text(
                                  'Sistem Informasi Kepegawaian',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF4A5568),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),

                                Container(
                                  width: 60,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF0D8A47),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Positioned(
                            right: 12,
                            bottom: 8, 
                            child: Text(
                              'v. 1.0',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // FORM SECTION
                  Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Log In',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // NIP FIELD
                          const Text(
                            'Nomor Induk Pegawai (NIP)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nipController,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Masukkan NIP Anda',
                              hintStyle: const TextStyle(
                                color: Color(0xFFA0AEC0),
                              ),
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                color: Color(0xFF0D8A47),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0D8A47),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF7FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'NIP tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // PASSWORD FIELD
                          const Text(
                            'Kata Sandi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Masukkan kata sandi',
                              hintStyle: const TextStyle(
                                color: Color(0xFFA0AEC0),
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF0D8A47),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: const Color(0xFF718096),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.5,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0D8A47),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF7FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Kata sandi tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // FORGOT PASSWORD
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Hubungi administrator untuk reset password',
                                    ),
                                    backgroundColor: Color(0xFF0D8A47),
                                  ),
                                );
                              },
                              child: const Text(
                                'Lupa Kata Sandi?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0D8A47),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // LOGIN BUTTON
                          SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D8A47),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                shadowColor: const Color(0xFF0D8A47)
                                    .withOpacity(0.4),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Masuk',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // DIVIDER
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'atau',
                                  style: TextStyle(
                                    color: Color(0xFFA0AEC0),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // REGISTER BUTTON
                          SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF0D8A47),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Registrasi Akun Baru',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D8A47),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // FOOTER
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/batik1.png'),
                        fit: BoxFit.cover,
                        opacity: 0.15,
                      ),
                      color: Colors.white.withOpacity(0.95),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.phone_outlined,
                              size: 16,
                              color: Color(0xFF2D3748),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Bantuan: (021) 4892507',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2D3748),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.email_outlined,
                              size: 16,
                              color: Color(0xFF2D3748),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'admin@poltekkesjkt2.ac.id',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2D3748),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '© 2024 Poltekkes Kemenkes Jakarta II',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF4A5568).withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}