import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cryptography/cryptography.dart';
import '../core/crypto/crypto_service.dart';

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

/// Holds the current teacher's Ed25519 key pair.
final teacherKeyPairProvider = FutureProvider<SimpleKeyPair>((ref) async {
  final crypto = ref.watch(cryptoServiceProvider);
  // In production this is loaded from secure hardware storage; for demo we generate or seed
  return await crypto.generateEd25519KeyPair();
});

/// Holds the current student's Ed25519 key pair.
final studentKeyPairProvider = FutureProvider<SimpleKeyPair>((ref) async {
  final crypto = ref.watch(cryptoServiceProvider);
  return await crypto.generateEd25519KeyPair();
});
