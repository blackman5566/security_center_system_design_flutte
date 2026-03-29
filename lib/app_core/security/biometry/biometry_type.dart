// biometry_type.dart
//
// Mirrors: BiometryType.swift

/// 裝置支援的生物辨識類型
enum BiometryType {
  faceId,
  touchId;

  String get title {
    switch (this) {
      case BiometryType.faceId:
        return 'Face ID';
      case BiometryType.touchId:
        return 'Touch ID';
    }
  }

  String get iconName {
    switch (this) {
      case BiometryType.faceId:
        return 'faceid';
      case BiometryType.touchId:
        return 'touchid';
    }
  }
}
