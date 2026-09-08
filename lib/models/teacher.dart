class Teacher {
  final String teacherId;
  final String name;
  final String publicKey;
  final String? privateKeyHash;

  const Teacher({
    required this.teacherId,
    required this.name,
    required this.publicKey,
    this.privateKeyHash,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacher_id': teacherId,
      'name': name,
      'public_key': publicKey,
      'private_key_hash': privateKeyHash,
    };
  }

  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      teacherId: map['teacher_id'] as String,
      name: map['name'] as String,
      publicKey: map['public_key'] as String,
      privateKeyHash: map['private_key_hash'] as String?,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Teacher.fromJson(Map<String, dynamic> json) => Teacher.fromMap(json);
}
