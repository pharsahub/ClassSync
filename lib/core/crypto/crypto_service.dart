import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Cryptographic service providing Ed25519 digital signatures,
/// AES-256-GCM authenticated encryption/decryption, and SHA-256 hashing.
class CryptoService {
  final Ed25519 _ed25519 = Ed25519();
  final AesGcm _aesGcm = AesGcm.with256bits();
  final Sha256 _sha256 = Sha256();

  // -------------------------------------------------------------
  // Ed25519 SIGNATURES & KEY MANAGEMENT
  // -------------------------------------------------------------

  /// Generates a new random Ed25519 key pair.
  Future<SimpleKeyPair> generateEd25519KeyPair() async {
    return await _ed25519.newKeyPair();
  }

  /// Generates an Ed25519 key pair deterministically from a 32-byte seed.
  Future<SimpleKeyPair> generateEd25519KeyPairFromSeed(List<int> seed) async {
    return await _ed25519.newKeyPairFromSeed(seed);
  }

  /// Exports a public key to a hex-encoded string.
  Future<String> exportPublicKeyHex(SimpleKeyPair keyPair) async {
    final pubKey = await keyPair.extractPublicKey();
    return _bytesToHex(pubKey.bytes);
  }

  /// Exports a private key to a hex-encoded string.
  Future<String> exportPrivateKeyHex(SimpleKeyPair keyPair) async {
    final privKeyData = await keyPair.extract();
    return _bytesToHex(privKeyData.bytes);
  }

  /// Imports an Ed25519 public key from a hex string.
  SimplePublicKey importPublicKeyFromHex(String hexString) {
    final bytes = _hexToBytes(hexString);
    return SimplePublicKey(bytes, type: KeyPairType.ed25519);
  }

  /// Imports an Ed25519 key pair from a hex private key (and optionally hex public key).
  SimpleKeyPair importKeyPairFromHex(String privateKeyHex, [String? publicKeyHex]) {
    final privBytes = _hexToBytes(privateKeyHex);
    final pubBytes = publicKeyHex != null ? _hexToBytes(publicKeyHex) : null;
    return SimpleKeyPairData(
      privBytes,
      publicKey: pubBytes != null
          ? SimplePublicKey(pubBytes, type: KeyPairType.ed25519)
          : SimplePublicKey(privBytes, type: KeyPairType.ed25519), // Fallback
      type: KeyPairType.ed25519,
    );
  }

  /// Signs a message string with an Ed25519 key pair and returns the hex signature.
  Future<String> signMessage(String message, SimpleKeyPair keyPair) async {
    final bytes = utf8.encode(message);
    final signature = await _ed25519.sign(bytes, keyPair: keyPair);
    return _bytesToHex(signature.bytes);
  }

  /// Verifies an Ed25519 signature against a message string and public key.
  Future<bool> verifySignature({
    required String message,
    required String signatureHex,
    required String publicKeyHex,
  }) async {
    try {
      final messageBytes = utf8.encode(message);
      final sigBytes = _hexToBytes(signatureHex);
      final pubKey = importPublicKeyFromHex(publicKeyHex);
      final signature = Signature(sigBytes, publicKey: pubKey);

      return await _ed25519.verify(messageBytes, signature: signature);
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------
  // AES-256-GCM ENCRYPTION / DECRYPTION
  // -------------------------------------------------------------

  /// Generates a new random 256-bit AES secret key.
  Future<SecretKey> generateAesKey() async {
    return await _aesGcm.newSecretKey();
  }

  /// Generates an AES key from a hex string.
  SecretKey importAesKeyFromHex(String hexKey) {
    return SecretKey(_hexToBytes(hexKey));
  }

  /// Exports an AES key to a hex string.
  Future<String> exportAesKeyHex(SecretKey secretKey) async {
    final bytes = await secretKey.extractBytes();
    return _bytesToHex(bytes);
  }

  /// Encrypts plaintext string using AES-256-GCM.
  /// Returns a JSON-serialized SecretBox map with ciphertext, nonce, and mac in hex.
  Future<Map<String, String>> encryptPayload(String plaintext, SecretKey secretKey) async {
    final plaintextBytes = utf8.encode(plaintext);
    final secretBox = await _aesGcm.encrypt(plaintextBytes, secretKey: secretKey);
    return {
      'ciphertext': _bytesToHex(secretBox.cipherText),
      'nonce': _bytesToHex(secretBox.nonce),
      'mac': _bytesToHex(secretBox.mac.bytes),
    };
  }

  /// Decrypts AES-256-GCM encrypted payload map.
  Future<String> decryptPayload(Map<String, String> encryptedMap, SecretKey secretKey) async {
    final cipherText = _hexToBytes(encryptedMap['ciphertext']!);
    final nonce = _hexToBytes(encryptedMap['nonce']!);
    final mac = Mac(_hexToBytes(encryptedMap['mac']!));

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
    final decryptedBytes = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(decryptedBytes);
  }

  // -------------------------------------------------------------
  // SHA-256 HASHING
  // -------------------------------------------------------------

  /// Computes the SHA-256 hash of a string and returns a hex string.
  Future<String> hashString(String input) async {
    final bytes = utf8.encode(input);
    final hash = await _sha256.hash(bytes);
    return _bytesToHex(hash.bytes);
  }

  /// Computes the SHA-256 hash of raw byte array.
  Future<String> hashBytes(List<int> bytes) async {
    final hash = await _sha256.hash(bytes);
    return _bytesToHex(hash.bytes);
  }

  // -------------------------------------------------------------
  // UTILITY CONVERSIONS
  // -------------------------------------------------------------

  static String bytesToHex(List<int> bytes) => _bytesToHex(bytes);
  static Uint8List hexToBytes(String hex) => _hexToBytes(hex);

  static String _bytesToHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static Uint8List _hexToBytes(String hex) {
    final cleanHex = hex.replaceAll(RegExp(r'\s+'), '');
    final result = Uint8List(cleanHex.length ~/ 2);
    for (int i = 0; i < cleanHex.length; i += 2) {
      result[i ~/ 2] = int.parse(cleanHex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
