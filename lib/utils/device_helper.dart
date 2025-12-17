import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceHelper {
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo android = await deviceInfo.androidInfo;
        return android.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo ios = await deviceInfo.iosInfo;
        return ios.identifierForVendor ?? '';
      }
    } catch (e) {
      print('Error getting device ID: $e');
    }
    
    return '';
  }
}