import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // ============================================
  // GANTI URL INI SESUAI ENVIRONMENT ANDA
  // ============================================
  
  // Untuk Android Emulator (localhost)
  static const String baseUrl = 'http://10.5.3.49/siak/public/api';
  
  // Untuk Android Device via WiFi (ganti dengan IP komputer Anda)
  // static const String baseUrl = 'http://192.168.1.100/simpeg/public/api';
  
  // Untuk Production (domain online)
  // static const String baseUrl = 'https://yourdomain.com/api';
  
  /// Check NIP - Cek apakah NIP ada dan belum terdaftar
  /// GET /api/check-nip/{nip}
  static Future<Map<String, dynamic>> checkNip(String nip) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/check-nip/$nip'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Gagal menghubungi server (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Register - Daftarkan user baru
  /// POST /api/register
  static Future<Map<String, dynamic>> register({
    required String nip,
    required String password,
    required String passwordConfirm,
    required String noHandphone,
    required String emailPribadi,
    required String deviceId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nip': nip,
          'password': password,
          'password_confirm': passwordConfirm,
          'no_handphone': noHandphone,
          'email_pribadi': emailPribadi,
          'device_id': deviceId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Gagal menghubungi server (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Login - Autentikasi user
  /// POST /api/login
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
          'device_id': deviceId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Gagal menghubungi server (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Get Profile - Ambil data profil lengkap
  /// GET /api/profile
      static Future<Map<String, dynamic>> getProfile(String token) async {
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/profile'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          if (response.statusCode == 200) {
            return json.decode(response.body);
          } else {
            return {
              'success': false,
              'message': 'Gagal menghubungi server (${response.statusCode})',
            };
          }
        } catch (e) {
          return {
            'success': false,
            'message': 'Error: $e',
          };
        }
      }

      static Future<Map<String, dynamic>> uploadFotoProfil({
      required String token,
      required File imageFile,
            }) async {
              try {
                var request = http.MultipartRequest(
                  'POST',
                  Uri.parse('$baseUrl/upload-foto'),
                );

          request.headers['Authorization'] = 'Bearer $token';

          var stream = http.ByteStream(imageFile.openRead());
          var length = await imageFile.length();
          var multipartFile = http.MultipartFile(
            'foto', // ✅ Ini sudah benar sesuai CI4
            stream,
            length,
            filename: imageFile.path.split('/').last,
          );
          request.files.add(multipartFile);

          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            return json.decode(response.body);
          } else {
            // Tambah debug info
            print('Status Code: ${response.statusCode}');
            print('Response Body: ${response.body}');
            
            return {
              'success': false,
              'message': 'Gagal upload foto: ${response.statusCode} - ${response.body}',
            };
          }
        } catch (e) {
          print('Error upload: $e');
          return {
            'success': false,
            'message': 'Error: $e',
          };
        }
      }

  /// Ubah Password
  /// POST /api/ubah-password
  static Future<Map<String, dynamic>> ubahPassword({
    required String token,
    required String passwordLama,
    required String passwordBaru,
    required String passwordBaruConfirm,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ubah-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'password_lama': passwordLama,
          'password_baru': passwordBaru,
          'password_baru_confirm': passwordBaruConfirm,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Gagal menghubungi server (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }
  /// Absen Masuk
/// POST /api/absen-masuk
static Future<Map<String, dynamic>> absenMasuk({
  required String token,
  required String deviceId,
  required String lokasiMasuk,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/absen-masuk'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'device_id': deviceId,
        'lokasi_masuk': lokasiMasuk,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {
        'success': false,
        'message': 'Gagal menghubungi server (${response.statusCode})',
      };
    }
  } catch (e) {
    return {
      'success': false,
      'message': 'Error: $e',
    };
  }
}

/// Absen Pulang
/// POST /api/absen-pulang
static Future<Map<String, dynamic>> absenPulang({
  required String token,
  required String deviceId,
  required String lokasiKeluar,
}) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/absen-pulang'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'device_id': deviceId,
        'lokasi_keluar': lokasiKeluar,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {
        'success': false,
        'message': 'Gagal menghubungi server (${response.statusCode})',
      };
    }
  } catch (e) {
    return {
      'success': false,
      'message': 'Error: $e',
    };
  }
}

/// Get Riwayat Absensi
/// GET /api/riwayat-absensi?bulan=12&tahun=2024
static Future<Map<String, dynamic>> getRiwayatAbsensi({
  required String token,
  int? bulan,
  int? tahun,
}) async {
  try {
    String url = '$baseUrl/riwayat-absensi';
    if (bulan != null || tahun != null) {
      url += '?';
      if (bulan != null) url += 'bulan=$bulan&';
      if (tahun != null) url += 'tahun=$tahun';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {
        'success': false,
        'message': 'Gagal menghubungi server (${response.statusCode})',
      };
    }
  } catch (e) {
    return {
      'success': false,
      'message': 'Error: $e',
    };
  }
}
}