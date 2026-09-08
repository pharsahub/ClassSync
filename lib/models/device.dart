class Device {
  final String deviceId;
  final String studentId;
  final String platform;

  const Device({
    required this.deviceId,
    required this.studentId,
    required this.platform,
  });

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'student_id': studentId,
      'platform': platform,
    };
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      deviceId: map['device_id'] as String,
      studentId: map['student_id'] as String,
      platform: map['platform'] as String,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Device.fromJson(Map<String, dynamic> json) => Device.fromMap(json);
}
