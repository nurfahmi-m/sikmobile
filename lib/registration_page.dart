import 'package:flutter/material.dart';
import 'utils/device_helper.dart';
import 'services/api_service.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nipController = TextEditingController();
  final _namaController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _pangkatController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _teleponController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isDataLoaded = false;
  bool _isPasswordVisible = false;
  bool _isPasswordConfirmVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nipController.dispose();
    _namaController.dispose();
    _jabatanController.dispose();
    _pangkatController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _teleponController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Load data pegawai dari API berdasarkan NIP
  void _loadDataFromNip() async {
    final nip = _nipController.text.trim();

    if (nip.isEmpty) {
      setState(() {
        _isDataLoaded = false;
        _namaController.clear();
        _jabatanController.clear();
        _pangkatController.clear();
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.checkNip(nip);

      if (response['success'] == true) {
        // NIP ditemukan dan belum terdaftar
        final data = response['data'];

        setState(() {
          _namaController.text = data['nama_peg'] ?? '';
          _jabatanController.text = data['jabatan'] ?? '';
          _pangkatController.text = data['pangkat_gol'] ?? '';
          
          // Auto-fill HP & Email jika sudah ada di database
          _teleponController.text = data['no_handphone'] ?? '';
          _emailController.text = data['email_pribadi'] ?? '';
          
          _isDataLoaded = true;
        });

        if (mounted) {
          String message = 'Data pegawai ditemukan!';
          
          // Beri info jika HP/Email sudah terisi
          if (data['no_handphone'] != null && data['no_handphone'].toString().isNotEmpty) {
            message += '\n\nℹ️ Nomor HP sudah terisi, Anda bisa mengubahnya jika ada perubahan.';
          }
          if (data['email_pribadi'] != null && data['email_pribadi'].toString().isNotEmpty) {
            message += '\n\nℹ️ Email sudah terisi, Anda bisa mengubahnya jika ada perubahan.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // NIP tidak ditemukan atau sudah terdaftar
        setState(() {
          _namaController.clear();
          _jabatanController.clear();
          _pangkatController.clear();
          _isDataLoaded = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'NIP tidak ditemukan'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Handle registrasi - Hit API Register
  void _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      if (!_isDataLoaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NIP tidak ditemukan dalam database'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Ambil Device ID
        String deviceId = await DeviceHelper.getDeviceId();

        if (deviceId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gagal mendapatkan Device ID'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Hit API Register
        final response = await ApiService.register(
          nip: _nipController.text.trim(),
          password: _passwordController.text,
          passwordConfirm: _passwordConfirmController.text,
          noHandphone: _teleponController.text.trim(),
          emailPribadi: _emailController.text.trim(),
          deviceId: deviceId,
        );

        if (mounted) {
          if (response['success'] == true) {
            // Registrasi berhasil
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message'] ?? 'Registrasi berhasil!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );

            // Kembali ke halaman login setelah 1 detik
            await Future.delayed(const Duration(seconds: 1));
            if (mounted) {
              Navigator.pop(context);
            }
          } else {
            // Registrasi gagal
            String errorMessage = response['message'] ?? 'Registrasi gagal';

            // Jika ada detail error dari validasi
            if (response['errors'] != null) {
              final errors = response['errors'] as Map<String, dynamic>;
              errorMessage = errors.values.join('\n');
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
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
                    padding: const EdgeInsets.all(24),
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
                          'Registrasi Akun',
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
                          'Daftarkan akun Anda untuk mengakses sistem',
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
                            color: const Color(0xFF0D8A47),
                            borderRadius: BorderRadius.circular(2),
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
                            onChanged: (value) {
                              if (value.isEmpty) {
                                setState(() {
                                  _isDataLoaded = false;
                                  _namaController.clear();
                                  _jabatanController.clear();
                                  _pangkatController.clear();
                                });
                              }
                            },
                            onFieldSubmitted: (value) => _loadDataFromNip(),
                            decoration: InputDecoration(
                              hintText: 'Masukkan NIP Anda',
                              hintStyle: const TextStyle(
                                color: Color(0xFFA0AEC0),
                              ),
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                color: Color(0xFF0D8A47),
                              ),
                              suffixIcon: _isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Color(0xFF0D8A47),
                                          ),
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.search,
                                        color: Color(0xFF0D8A47),
                                      ),
                                      onPressed: _loadDataFromNip,
                                      tooltip: 'Cari data pegawai',
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

                          // NAMA LENGKAP FIELD (READ ONLY)
                          const Text(
                            'Nama Lengkap',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _namaController,
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'Nama akan terisi otomatis',
                              hintStyle: const TextStyle(
                                color: Color(0xFFA0AEC0),
                              ),
                              prefixIcon: const Icon(
                                Icons.person_outline,
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
                              filled: true,
                              fillColor: const Color(0xFFF7FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // JABATAN FIELD (READ ONLY)
                          const Text(
                            'Jabatan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _jabatanController,
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'Jabatan akan terisi otomatis',
                              hintStyle: const TextStyle(
                                color: Color(0xFFA0AEC0),
                              ),
                              prefixIcon: const Icon(
                                Icons.work_outline,
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
                              filled: true,
                              fillColor: const Color(0xFFF7FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // PANGKAT/GOLONGAN FIELD (READ ONLY)
                          const Text(
                            'Pangkat / Golongan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pangkatController,
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'Pangkat/Golongan akan terisi otomatis',
                              hintStyle: const TextStyle(
                                color: Color(0xFFA0AEC0),
                              ),
                              prefixIcon: const Icon(
                                Icons.military_tech_outlined,
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
                              filled: true,
                              fillColor: const Color(0xFFF7FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
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
                              hintText: 'Minimal 6 karakter',
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
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFF0D8A47),
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
                              if (value.length < 6) {
                                return 'Kata sandi minimal 6 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // KONFIRMASI PASSWORD FIELD
                          const Text(
                            'Konfirmasi Kata Sandi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordConfirmController,
                            obscureText: !_isPasswordConfirmVisible,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Masukkan ulang kata sandi',
                              hintStyle: const TextStyle(
                                color: Color(0xFFA0AEC0),
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF0D8A47),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordConfirmVisible
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFF0D8A47),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordConfirmVisible =
                                        !_isPasswordConfirmVisible;
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
                              if (value != _passwordController.text) {
                                return 'Kata sandi tidak cocok';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // NOMOR TELEPON FIELD
                          const Text(
                            'Nomor Telepon',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _teleponController,
                            keyboardType: TextInputType.phone,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Contoh: 081234567890',
                              hintStyle: const TextStyle(
                                color: Color(0xFFA0AEC0),
                              ),
                              prefixIcon: const Icon(
                                Icons.phone_outlined,
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
                                return 'Nomor telepon tidak boleh kosong';
                              }
                              if (!RegExp(r'^[0-9]{10,13}$').hasMatch(value)) {
                                return 'Nomor telepon tidak valid (10-13 digit)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // EMAIL FIELD
                          const Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'mail@email.com',
                              hintStyle: const TextStyle(
                                color: Color(0xFFA0AEC0),
                              ),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
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
                                return 'Email tidak boleh kosong';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Email tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // REGISTER BUTTON
                          SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegistration,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D8A47),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFFE2E8F0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                shadowColor:
                                    const Color(0xFF0D8A47).withOpacity(0.4),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Daftar',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // BACK TO LOGIN BUTTON
                          SizedBox(
                            height: 52,
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                    },
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
                                'Kembali ke Login',
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
                              'Bantuan: 0812-8822-4589',
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
                              'muhammad.nur.fahmi@poltekkesjkt2.ac.id',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2D3748),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 8),
                            Text(
                              'Unit Kepegawaian - 2025',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF4A5568).withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Poltekkes Kemenkes Jakarta II',
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