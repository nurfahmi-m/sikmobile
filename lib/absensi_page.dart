
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:math' show cos, sqrt, asin;
import 'services/api_service.dart';

class AbsensiPage extends StatefulWidget {
  final String nama;
  final String nip;
  final String? fotoUrl;
  final bool useFingerprintMode;

  const AbsensiPage({
    super.key,
    required this.nama,
    required this.nip,
    required this.useFingerprintMode,
    this.fotoUrl,
  });

  @override
  State<AbsensiPage> createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  static const double KANTOR_LAT = -6.238883695680261;
  static const double KANTOR_LNG = 106.7936581961598;
  static const double RADIUS_METER = 150.0;
  
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  String _currentLocation = 'Mendapatkan lokasi...';
  bool _isLoadingLocation = true;
  final Set<Marker> _markers = {};

  // PERUBAHAN: Tambahkan flag _isLocationReady
  bool _isLocationReady = false;
  bool _isInRadius = false;
  double _jarakDariKantor = 0.0;

  String? _token;
  String? _deviceId;
  List<Map<String, dynamic>> _historyAbsensi = [];
  bool _isLoadingHistory = false;

  final List<String> _namaHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  final List<String> _namaBulan = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

  String _formatTanggalIndonesia(DateTime date) {
    return '${_namaHari[date.weekday - 1]}, ${date.day} ${_namaBulan[date.month - 1]} ${date.year}';
  }

  String _formatTanggalSingkat(DateTime date) {
    return '${date.day} ${_namaBulan[date.month - 1]} ${date.year}';
  }

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _loadTokenAndDeviceId();
    await _getCurrentLocation();
    await _loadRiwayatAbsensi();
  }

  Future<void> _loadTokenAndDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_token');
    
    final deviceInfo = DeviceInfoPlugin();
    if (Theme.of(context).platform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      _deviceId = androidInfo.id;
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _deviceId = iosInfo.identifierForVendor;
    }
  }

  Future<void> _loadRiwayatAbsensi() async {
    if (_token == null) return;
    setState(() => _isLoadingHistory = true);

    try {
      final now = DateTime.now();
      final response = await ApiService.getRiwayatAbsensi(token: _token!, bulan: now.month, tahun: now.year);
      if (response['success'] == true) {
        setState(() {
          _historyAbsensi = List<Map<String, dynamic>>.from(response['data']['riwayat'] ?? []);
          _isLoadingHistory = false;
        });
      } else {
        setState(() => _isLoadingHistory = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Gagal memuat riwayat'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      setState(() => _isLoadingHistory = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  double _hitungJarak(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final double a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }

  bool _cekLokasiDalamRadius(double userLat, double userLng) {
    final jarak = _hitungJarak(KANTOR_LAT, KANTOR_LNG, userLat, userLng);
    setState(() {
      _jarakDariKantor = jarak;
      _isInRadius = jarak <= RADIUS_METER;
    });
    return _isInRadius;
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoadingLocation = true;
        _isLocationReady = false; // PERUBAHAN: Reset flag
      });

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentLocation = 'Layanan lokasi tidak aktif';
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentLocation = 'Izin lokasi ditolak';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentLocation = 'Izin lokasi ditolak permanen';
          _isLoadingLocation = false;
        });
        return;
      }

      if (Theme.of(context).platform == TargetPlatform.android) {
        try {
          final bool? isMock = await const MethodChannel('sik/mock_location').invokeMethod<bool>('isMockLocation');
          if (isMock == true) {
            setState(() {
              _currentLocation = 'Lokasi palsu terdeteksi';
              _isLoadingLocation = false;
            });
            return;
          }
        } catch (e) {}
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _cekLokasiDalamRadius(position.latitude, position.longitude);

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLocationReady = true; // PERUBAHAN: Set flag setelah lokasi didapat
        
        _markers.clear();
        _markers.add(Marker(
          markerId: const MarkerId('current_location'),
          position: _currentPosition!,
          infoWindow: InfoWindow(
            title: 'Lokasi Anda',
            snippet: _isInRadius ? '✓ Dalam radius (${_jarakDariKantor.toStringAsFixed(0)}m)' : '✗ Di luar radius (${_jarakDariKantor.toStringAsFixed(0)}m)',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(_isInRadius ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed),
        ));
        _markers.add(Marker(
          markerId: const MarkerId('office_location'),
          position: const LatLng(KANTOR_LAT, KANTOR_LNG),
          infoWindow: const InfoWindow(title: 'Lokasi Kantor', snippet: 'Area absensi'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ));
      });

      await _getAddressFromCoordinates(position.latitude, position.longitude);

      if (_mapController != null && _currentPosition != null) {
        final bounds = LatLngBounds(
          southwest: LatLng(_currentPosition!.latitude < KANTOR_LAT ? _currentPosition!.latitude : KANTOR_LAT, _currentPosition!.longitude < KANTOR_LNG ? _currentPosition!.longitude : KANTOR_LNG),
          northeast: LatLng(_currentPosition!.latitude > KANTOR_LAT ? _currentPosition!.latitude : KANTOR_LAT, _currentPosition!.longitude > KANTOR_LNG ? _currentPosition!.longitude : KANTOR_LNG),
        );
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      }
    } catch (e) {
      setState(() {
        _currentLocation = 'Gagal mendapatkan lokasi: $e';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentLocation = '${place.street}, ${place.subLocality}, ${place.locality}, ${place.subAdministrativeArea}';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentLocation = 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
        _isLoadingLocation = false;
      });
    }
  }

  Future<bool> _validasiLokasiSebelumAbsen(String jenisAbsen) async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      try {
        final bool? isDev = await const MethodChannel('sik/mock_location').invokeMethod<bool>('isDeveloperMode');
        if (isDev == true) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Developer Mode Aktif'),
                content: const Text('Nonaktifkan Developer Mode atau Mock Location sebelum melakukan absensi.'),
                actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup'))],
              ),
            );
          }
          return false;
        }
      } catch (e) {}
    }

    if (_currentPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lokasi belum terdeteksi. Mohon tunggu sebentar.'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
      }
      return false;
    }

    if (!_isInRadius) {
      _showLokasiDiluarRadiusDialog(jenisAbsen);
      return false;
    }

    return true;
  }

  void _showLokasiDiluarRadiusDialog(String jenisAbsen) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: const [
            Icon(Icons.location_off, color: Color(0xFFE53E3E), size: 24),
            SizedBox(width: 12),
            Expanded(child: Text('Lokasi Di Luar Jangkauan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3748), fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.error_outline, color: Color(0xFFE53E3E), size: 20),
                      SizedBox(width: 8),
                      Text('Absensi Tidak Dapat Dilakukan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3748), fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Jarak Anda saat ini: ${_jarakDariKantor.toStringAsFixed(0)} meter dari kantor', style: const TextStyle(fontSize: 13, color: Color(0xFF718096))),
                  const SizedBox(height: 8),
                  Text('Radius yang diizinkan: ${RADIUS_METER.toStringAsFixed(0)} meter', style: const TextStyle(fontSize: 13, color: Color(0xFF718096))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Silakan mendekat ke area kantor untuk melakukan absensi.', style: TextStyle(fontSize: 13, color: Color(0xFF718096))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _getCurrentLocation();
            },
            child: const Text('Coba Lagi', style: TextStyle(color: Color(0xFF40C89D), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53E3E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            child: const Text('Tutup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _authenticateWithFingerprint(String jenisAbsen) async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device Anda tidak mendukung autentikasi sidik jari'), backgroundColor: Colors.red));
        }
        return false;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: jenisAbsen == 'datang' ? 'Scan sidik jari untuk absen datang' : 'Scan sidik jari untuk absen pulang',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );

      return didAuthenticate;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error autentikasi: $e'), backgroundColor: Colors.red));
      }
      return false;
    }
  }

  Future<void> _prosesAbsenMasuk() async {
    if (_token == null || _deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token atau Device ID tidak ditemukan'), backgroundColor: Colors.red));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      final response = await ApiService.absenMasuk(token: _token!, deviceId: _deviceId!, lokasiMasuk: _currentLocation);
      if (mounted) Navigator.of(context).pop();

      if (response['success'] == true) {
        await _loadRiwayatAbsensi();
        if (mounted) _showSuccessDialog('datang', response['data']);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Gagal absen masuk'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _prosesAbsenPulang() async {
    if (_token == null || _deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token atau Device ID tidak ditemukan'), backgroundColor: Colors.red));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      final response = await ApiService.absenPulang(token: _token!, deviceId: _deviceId!, lokasiKeluar: _currentLocation);
      if (mounted) Navigator.of(context).pop();

      if (response['success'] == true) {
        await _loadRiwayatAbsensi();
        if (mounted) _showSuccessDialog('pulang', response['data']);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'Gagal absen pulang'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showSuccessDialog(String jenisAbsen, Map<String, dynamic> data) {
    final isDatang = jenisAbsen == 'datang';
    final now = DateTime.now();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        contentPadding: const EdgeInsets.all(20),
        title: Row(
          children: [
            Icon(isDatang ? Icons.check_circle : Icons.logout, color: isDatang ? const Color(0xFF0D8A47) : const Color(0xFFE53E3E), size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(isDatang ? 'Absen Datang Berhasil' : 'Absen Pulang Berhasil', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3748), fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: isDatang ? const Color(0xFFF0F9F4) : const Color(0xFFFFF5F5), shape: BoxShape.circle),
              child: Icon(Icons.check, size: 60, color: isDatang ? const Color(0xFF0D8A47) : const Color(0xFFE53E3E)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isDatang ? const Color(0xFFF0F9F4) : const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_today, size: 16), const SizedBox(width: 8), Text(data['hari'] ?? _formatTanggalSingkat(now), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2D3748), fontSize: 13))]),
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.access_time, size: 16), const SizedBox(width: 8), Text(isDatang ? data['jam_masuk'] : data['jam_keluar'], style: TextStyle(fontWeight: FontWeight.bold, color: isDatang ? const Color(0xFF0D8A47) : const Color(0xFFE53E3E), fontSize: 18))]),
                  if (isDatang && data['status_terlambat'] == true) ...[
                    const SizedBox(height: 8),
                    Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.warning, size: 16, color: Color(0xFFE53E3E)), const SizedBox(width: 8), Text('Terlambat: ${data['terlambat']}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE53E3E), fontSize: 13))]),
                  ],
                  if (!isDatang && data['status_pulang_awal'] == true) ...[
                    const SizedBox(height: 8),
                    Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.warning, size: 16, color: Color(0xFFE53E3E)), const SizedBox(width: 8), Text('Pulang Awal: ${data['pulang_awal']}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE53E3E), fontSize: 13))]),
                  ],
                  if (!isDatang && data['status_lembur'] == true) ...[
                    const SizedBox(height: 8),
                    Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star, size: 16, color: Color(0xFF0D8A47)), const SizedBox(width: 8), Text('Lembur: ${data['waktu_lembur']}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0D8A47), fontSize: 13))]),
                  ],
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_on, size: 16, color: Color(0xFF0D8A47)), const SizedBox(width: 8), Text('${_jarakDariKantor.toStringAsFixed(0)}m dari kantor', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0D8A47), fontSize: 13))]),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: isDatang ? const Color(0xFF0D8A47) : const Color(0xFFE53E3E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAbsenDatang() async {
    if (!await _validasiLokasiSebelumAbsen('datang')) return;
    if (widget.useFingerprintMode) {
      final authenticated = await _authenticateWithFingerprint('datang');
      if (authenticated) await _prosesAbsenMasuk();
    } else {
      await _prosesAbsenMasuk();
    }
  }

  Future<void> _handleAbsenPulang() async {
    if (!await _validasiLokasiSebelumAbsen('pulang')) return;
    if (widget.useFingerprintMode) {
      final authenticated = await _authenticateWithFingerprint('pulang');
      if (authenticated) await _prosesAbsenPulang();
    } else {
      await _prosesAbsenPulang();
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
            stops: const [0.0, 0.25, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Absensi Online',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.useFingerprintMode
                                ? Icons.fingerprint
                                : Icons.check_circle_outline,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.useFingerprintMode ? 'Sidik Jari' : 'Langsung',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // INFO PENGGUNA
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9F4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  widget.fotoUrl ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/images/user.png',
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.nama,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'NIP: ${widget.nip}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF718096),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // STATUS LOKASI
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isInRadius 
                              ? const Color(0xFFF0F9F4)
                              : const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isInRadius 
                                ? const Color(0xFF0D8A47)
                                : const Color(0xFFE53E3E),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isInRadius ? Icons.check_circle : Icons.cancel,
                              color: _isInRadius 
                                  ? const Color(0xFF0D8A47)
                                  : const Color(0xFFE53E3E),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isInRadius 
                                        ? 'Lokasi Valid ✓'
                                        : 'Lokasi Di Luar Radius ✗',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _isInRadius 
                                          ? const Color(0xFF0D8A47)
                                          : const Color(0xFFE53E3E),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // PERUBAHAN: Hanya tampilkan detail jarak setelah lokasi siap
                                  if (_isLocationReady) ...[
                                    Row(
                                      children: [
                                        Icon(
                                          _jarakDariKantor <= RADIUS_METER
                                              ? Icons.location_on
                                              : Icons.location_off,
                                          size: 14,
                                          color: _jarakDariKantor <= RADIUS_METER
                                              ? Colors.green
                                              : Colors.redAccent,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _jarakDariKantor <= RADIUS_METER
                                                ? 'Anda berada dalam radius absensi'
                                                : 'Jarak: ${_jarakDariKantor.toStringAsFixed(0)}m dari kantor '
                                                  '(maks ${RADIUS_METER.toStringAsFixed(0)}m)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _jarakDariKantor <= RADIUS_METER
                                                  ? Colors.green
                                                  : Colors.redAccent,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.grey[600]!,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Mengecek lokasi...',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // GOOGLE MAPS CONTAINER
                      Container(
                        width: double.infinity,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            children: [
                              _currentPosition == null
                                  ? Container(
                                      color: const Color(0xFFE2E8F0),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Color(0xFF40C89D),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Mengambil lokasi...',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: _currentPosition!,
                                        zoom: 16.0,
                                      ),
                                      markers: _markers,
                                      circles: {
                                        Circle(
                                          circleId: const CircleId('radius'),
                                          center: const LatLng(KANTOR_LAT, KANTOR_LNG),
                                          radius: RADIUS_METER,
                                          fillColor: const Color(0xFF40C89D).withOpacity(0.2),
                                          strokeColor: const Color(0xFF40C89D),
                                          strokeWidth: 2,
                                        ),
                                      },
                                      myLocationEnabled: true,
                                      myLocationButtonEnabled: false,
                                      zoomControlsEnabled: false,
                                      mapType: MapType.normal,
                                      onMapCreated: (GoogleMapController controller) {
                                        _mapController = controller;
                                      },
                                    ),
                              
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.7),
                                      ],
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _isLoadingLocation
                                            ? const Text(
                                                'Mendapatkan alamat...',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                ),
                                              )
                                            : Text(
                                                _currentLocation,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: _getCurrentLocation,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(
                                        Icons.my_location,
                                        color: Color(0xFF40C89D),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // BUTTON ABSENSI
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _handleAbsenDatang,
                              icon: Icon(
                                widget.useFingerprintMode
                                    ? Icons.fingerprint
                                    : Icons.login,
                                size: 20,
                              ),
                              label: const Text(
                                'Absen Datang',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D8A47),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _handleAbsenPulang,
                              icon: Icon(
                                widget.useFingerprintMode
                                    ? Icons.fingerprint
                                    : Icons.logout,
                                size: 20,
                              ),
                              label: const Text(
                                'Absen Pulang',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE53E3E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // HISTORY SECTION
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Riwayat Absensi',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Data absensi bulan ini',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: _loadRiwayatAbsensi,
                            icon: const Icon(
                              Icons.refresh,
                              color: Color(0xFF40C89D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // HISTORY LIST
                      _isLoadingHistory
                          ? Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _historyAbsensi.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(40),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.inbox_outlined,
                                          size: 60,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Belum ada riwayat absensi',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _historyAbsensi.length,
                                    separatorBuilder: (context, index) => Divider(
                                      height: 1,
                                      color: Colors.grey[200],
                                    ),
                                    itemBuilder: (context, index) {
                                      final item = _historyAbsensi[index];
                                      final tanggal = DateTime.parse(item['tanggal']);
                                      final status = item['status'];
                                      final isHadir = status == 'Hadir';

                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isHadir
                                                    ? const Color(0xFFF0F9F4)
                                                    : const Color(0xFFFFF5F5),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                isHadir
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                color: isHadir
                                                    ? const Color(0xFF0D8A47)
                                                    : const Color(0xFFE53E3E),
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _formatTanggalIndonesia(tanggal),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF2D3748),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.login,
                                                        size: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        item['jam_masuk'] ?? '-',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[700],
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Icon(
                                                        Icons.logout,
                                                        size: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        item['jam_keluar'] ?? '-',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[700],
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isHadir
                                                    ? const Color(0xFFF0F9F4)
                                                    : const Color(0xFFFFF5F5),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                status,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isHadir
                                                      ? const Color(0xFF0D8A47)
                                                      : const Color(0xFFE53E3E),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}