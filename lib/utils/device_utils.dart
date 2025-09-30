import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceUtils {
  static String getPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      default:
        return 'unknown';
    }
  }


  static Future<String?> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = await deviceInfo.androidInfo;
      return android.id; // unique ID for the device (can change on factory reset)
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = await deviceInfo.iosInfo;
      return ios.identifierForVendor; // unique per app vendor on the device
    } else {
      return null;
    }
  }

  static Future<String> getAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version; // e.g. "1.0.3"
  }


}


