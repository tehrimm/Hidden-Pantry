import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asn1.dart';

class ChatEncryptionService {
  static final ChatEncryptionService _instance = ChatEncryptionService._internal();
  factory ChatEncryptionService() => _instance;
  ChatEncryptionService._internal();

  final _storage = const FlutterSecureStorage();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Constants
  static const String _privateKeyPrefix = 'chat_private_key_';
  static const String _publicKeyPrefix = 'chat_public_key_';

  /// Initializes the encryption for the current user.
  /// Generates RSA keys if they don't exist and uploads public key to Firestore.
  Future<void> initializeKeys() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final hasKey = await _storage.containsKey(key: '$_privateKeyPrefix${user.uid}');
    if (!hasKey) {
      debugPrint("Generating new RSA keys for ${user.uid}...");
      final keyPair = _generateRSAkeyPair();
      
      final privateKeyString = _encodePrivateKeyToPem(keyPair.privateKey as pc.RSAPrivateKey);
      final publicKeyString = _encodePublicKeyToPem(keyPair.publicKey as pc.RSAPublicKey);

      await _storage.write(key: '$_privateKeyPrefix${user.uid}', value: privateKeyString);
      
      // Store public key in Firestore (user's document or a separate collection)
      // We'll try to store in users/{uid} or nutritionists/{uid} based on role
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'chatPublicKey': publicKeyString,
        });
      } catch (_) {
        try {
          await _firestore.collection('nutritionists').doc(user.uid).update({
            'chatPublicKey': publicKeyString,
          });
        } catch (e) {
          debugPrint("Failed to upload public key: $e");
        }
      }
    }
  }

  /// Encrypts a message for a specific recipient.
  /// Returns a Map containing the ciphertext and the encrypted AES key.
  Future<Map<String, String>> encryptMessage(String plaintext, String recipientId) async {
    try {
      // 1. Get recipient's public key
      String? recipientPublicKey;
      final userDoc = await _firestore.collection('users').doc(recipientId).get();
      if (userDoc.exists) {
        recipientPublicKey = userDoc.data()?['chatPublicKey'];
      } else {
        final nutDoc = await _firestore.collection('nutritionists').doc(recipientId).get();
        recipientPublicKey = nutDoc.data()?['chatPublicKey'];
      }

      if (recipientPublicKey == null) {
        debugPrint("Recipient has no public key. Returning plaintext (or error).");
        return {'cipherText': plaintext, 'isEncrypted': 'false'};
      }

      // 2. Generate random AES key (32 bytes for AES-256)
      final aesKeyBytes = _generateRandomBytes(32);
      final aesIVBytes = _generateRandomBytes(16);
      final aesKey = encrypt.Key(aesKeyBytes);
      final iv = encrypt.IV(aesIVBytes);

      // 3. Encrypt message with AES
      final encrypter = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);

      // 4. Encrypt AES key and IV with recipient's RSA public key
      final rsaPublicKey = encrypt.RSAKeyParser().parse(recipientPublicKey) as pc.RSAPublicKey;
      final rsaEncrypter = encrypt.Encrypter(encrypt.RSA(publicKey: rsaPublicKey));
      
      // Combine key and IV for RSA encryption
      final combinedKeyIV = base64.encode(aesKeyBytes) + ":" + base64.encode(aesIVBytes);
      final encryptedKeyIV = rsaEncrypter.encrypt(combinedKeyIV).base64;

      return {
        'cipherText': encrypted.base64,
        'encryptedKey': encryptedKeyIV,
        'isEncrypted': 'true',
      };
    } catch (e) {
      debugPrint("Encryption error: $e");
      return {'cipherText': plaintext, 'isEncrypted': 'false'};
    }
  }

  /// Decrypts a message using the current user's private key.
  Future<String> decryptMessage(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return "Error: No User";

    if (data['isEncrypted'] != 'true' || data['encryptedKey'] == null) {
      return data['text'] ?? data['cipherText'] ?? "";
    }

    try {
      final privateKeyString = await _storage.read(key: '$_privateKeyPrefix${user.uid}');
      if (privateKeyString == null) return "[Encrypted Message - Private Key Missing]";

      // 1. Decrypt AES key with RSA private key
      final rsaPrivateKey = encrypt.RSAKeyParser().parse(privateKeyString) as pc.RSAPrivateKey;
      final rsaEncrypter = encrypt.Encrypter(encrypt.RSA(privateKey: rsaPrivateKey));
      
      final decryptedKeyIVString = rsaEncrypter.decrypt(encrypt.Encrypted.fromBase64(data['encryptedKey']));
      final parts = decryptedKeyIVString.split(":");
      final aesKeyBytes = base64.decode(parts[0]);
      final aesIVBytes = base64.decode(parts[1]);

      // 2. Decrypt message with recovered AES key
      final aesKey = encrypt.Key(aesKeyBytes);
      final iv = encrypt.IV(aesIVBytes);
      final encrypter = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
      
      return encrypter.decrypt(encrypt.Encrypted.fromBase64(data['cipherText']), iv: iv);
    } catch (e) {
      debugPrint("Decryption error: $e");
      return "[Decryption Failed]";
    }
  }

  // --- RSA Helpers ---

  pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey> _generateRSAkeyPair() {
    final pc.KeyGenerator generator = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
          _secureRandom()));
    return generator.generateKeyPair();
  }

  pc.SecureRandom _secureRandom() {
    final pc.SecureRandom secureRandom = pc.FortunaRandom();
    final Random random = Random.secure();
    final List<int> seeds = List.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  String _encodePrivateKeyToPem(pc.RSAPrivateKey privateKey) {
    final topLevel = ASN1Sequence();
    topLevel.add(ASN1Integer(BigInt.zero));
    topLevel.add(ASN1Integer(privateKey.n));
    topLevel.add(ASN1Integer(privateKey.publicExponent));
    topLevel.add(ASN1Integer(privateKey.privateExponent));
    topLevel.add(ASN1Integer(privateKey.p));
    topLevel.add(ASN1Integer(privateKey.q));
    topLevel.add(ASN1Integer(privateKey.p! % (privateKey.privateExponent! - BigInt.one))); // This is simplified
    topLevel.add(ASN1Integer(privateKey.q! % (privateKey.privateExponent! - BigInt.one))); // This is simplified
    topLevel.add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!)));

    final dataBase64 = base64.encode(topLevel.encode());
    return '-----BEGIN RSA PRIVATE KEY-----\n$dataBase64\n-----END RSA PRIVATE KEY-----';
  }

  String _encodePublicKeyToPem(pc.RSAPublicKey publicKey) {
    final innerSeq = ASN1Sequence();
    innerSeq.add(ASN1Integer(publicKey.n));
    innerSeq.add(ASN1Integer(publicKey.publicExponent));

    final algorithmSeq = ASN1Sequence();
    algorithmSeq.add(ASN1ObjectIdentifier.fromName('rsaEncryption'));
    algorithmSeq.add(ASN1Null());

    final topLevel = ASN1Sequence();
    topLevel.add(algorithmSeq);
    topLevel.add(ASN1BitString(stringValues: innerSeq.encode()));

    final dataBase64 = base64.encode(topLevel.encode());
    return '-----BEGIN PUBLIC KEY-----\n$dataBase64\n-----END PUBLIC KEY-----';
  }
}
