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
  static ChatEncryptionService? _instance;
  
  final FlutterSecureStorage _storage;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatEncryptionService._internal({
    FlutterSecureStorage? storage,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  factory ChatEncryptionService({
    FlutterSecureStorage? storage,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) {
    if (storage == null && firestore == null && auth == null) {
      _instance ??= ChatEncryptionService._internal();
      return _instance!;
    }
    return ChatEncryptionService._internal(
      storage: storage,
      firestore: firestore,
      auth: auth,
    );
  }

  // Constants
  static const String _privateKeyPrefix = 'chat_private_key_';
  static const String _publicKeyPrefix = 'chat_public_key_';

  // --- RSA Initialization & Storage ---

  Future<void> initializeKeys() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final keyPath = '$_privateKeyPrefix${user.uid}';
    String? jsonKeyData = await _storage.read(key: keyPath);
    
    bool isValid = false;
    if (jsonKeyData != null && jsonKeyData.startsWith('{')) {
      try {
        final Map<String, dynamic> keyMap = json.decode(jsonKeyData);
        final privateKey = _parsePrivateKeyFromJson(keyMap);
        
        // Self-test
        final testEncrypter = encrypt.Encrypter(encrypt.RSA(privateKey: privateKey));
        final testPublicEncrypter = encrypt.Encrypter(encrypt.RSA(publicKey: _derivePublicKey(privateKey)));
        final plain = "self_test_${user.uid}";
        final enc = testPublicEncrypter.encrypt(plain);
        if (testEncrypter.decrypt(enc) == plain) {
          isValid = true;
        }
      } catch (e) {
        debugPrint("JSON key invalid: $e");
      }
    }

    if (!isValid) {
      debugPrint("Regenerating RSA keys (JSON format) for ${user.uid}...");
      final keyPair = _generateRSAkeyPair();
      final priv = keyPair.privateKey as pc.RSAPrivateKey;
      final pub = keyPair.publicKey as pc.RSAPublicKey;

      final privateKeyJson = json.encode({
        'n': priv.n.toString(),
        'e': priv.publicExponent.toString(),
        'd': priv.privateExponent.toString(),
        'p': priv.p.toString(),
        'q': priv.q.toString(),
      });

      final publicKeyString = "${pub.n}:${pub.publicExponent}";

      await _storage.write(key: keyPath, value: privateKeyJson);
      await _syncPublicKeyToFirestore(user.uid, publicKeyString);
    }
  }

  pc.RSAPrivateKey _parsePrivateKeyFromJson(Map<String, dynamic> map) {
    return pc.RSAPrivateKey(
      BigInt.parse(map['n']),
      BigInt.parse(map['d']),
      BigInt.parse(map['p']),
      BigInt.parse(map['q']),
    );
  }

  pc.RSAPublicKey _parsePublicKeyFromString(String s) {
    final parts = s.split(":");
    return pc.RSAPublicKey(BigInt.parse(parts[0]), BigInt.parse(parts[1]));
  }

  pc.RSAPublicKey _derivePublicKey(pc.RSAPrivateKey priv) {
    return pc.RSAPublicKey(priv.n!, priv.publicExponent!);
  }

  Future<void> _syncPublicKeyToFirestore(String uid, String publicKeyString) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final nutRef = _firestore.collection('nutritionists').doc(uid);
      final uDoc = await userRef.get();
      if (uDoc.exists) {
        await userRef.update({'chatPublicKey': publicKeyString});
      } else {
        final nDoc = await nutRef.get();
        if (nDoc.exists) await nutRef.update({'chatPublicKey': publicKeyString});
      }
    } catch (_) {}
  }

  // --- Encryption & Decryption ---

  Future<Map<String, String>> encryptMessage(String plaintext, String recipientId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'cipherText': plaintext, 'isEncrypted': 'false'};

      // Fetch keys
      String? recipientPubStr;
      final rDoc = await _firestore.collection('users').doc(recipientId).get();
      recipientPubStr = rDoc.data()?['chatPublicKey'] ?? (await _firestore.collection('nutritionists').doc(recipientId).get()).data()?['chatPublicKey'];

      if (recipientPubStr == null || !recipientPubStr.contains(":")) {
        return {'cipherText': plaintext, 'isEncrypted': 'false'};
      }

      String? senderPubStr;
      final sDoc = await _firestore.collection('users').doc(user.uid).get();
      senderPubStr = sDoc.data()?['chatPublicKey'] ?? (await _firestore.collection('nutritionists').doc(user.uid).get()).data()?['chatPublicKey'];

      // AES Logic
      final aesKeyBytes = _generateRandomBytes(32);
      final aesIVBytes = _generateRandomBytes(16);
      final aesEncrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(aesKeyBytes), mode: encrypt.AESMode.cbc));
      final encryptedMessage = aesEncrypter.encrypt(plaintext, iv: encrypt.IV(aesIVBytes));
      final keyPayload = base64.encode(aesKeyBytes) + "|" + base64.encode(aesIVBytes);

      // RSA Logic for recipient
      final rsaRecipient = encrypt.Encrypter(encrypt.RSA(publicKey: _parsePublicKeyFromString(recipientPubStr)));
      final encKeyRecipient = rsaRecipient.encrypt(keyPayload).base64;

      // RSA Logic for sender (self-decryption)
      String? encKeySender;
      if (senderPubStr != null && senderPubStr.contains(":")) {
        final rsaSender = encrypt.Encrypter(encrypt.RSA(publicKey: _parsePublicKeyFromString(senderPubStr)));
        encKeySender = rsaSender.encrypt(keyPayload).base64;
      }

      return {
        'cipherText': encryptedMessage.base64,
        'encryptedKey': encKeyRecipient,
        'senderEncryptedKey': encKeySender ?? encKeyRecipient,
        'isEncrypted': 'true',
      };
    } catch (e) {
      debugPrint("Encryption error: $e");
      return {'cipherText': plaintext, 'isEncrypted': 'false'};
    }
  }

  Future<String> decryptMessage(Map<String, dynamic> data) async {
    if (data['isEncrypted'] != 'true') return data['text'] ?? "";
    final user = _auth.currentUser;
    if (user == null) return "[Error: No User]";

    try {
      final keyData = await _storage.read(key: '$_privateKeyPrefix${user.uid}');
      if (keyData == null || !keyData.startsWith('{')) return "[E2EE Setup Pending]";

      final privKey = _parsePrivateKeyFromJson(json.decode(keyData));
      final rsa = encrypt.Encrypter(encrypt.RSA(privateKey: privKey));

      final targetKey = (data['senderId'] == user.uid) ? (data['senderEncryptedKey'] ?? data['encryptedKey']) : data['encryptedKey'];
      final decryptedPayload = rsa.decrypt(encrypt.Encrypted.fromBase64(targetKey));
      
      final parts = decryptedPayload.split("|");
      final aesKey = encrypt.Key(base64.decode(parts[0]));
      final iv = encrypt.IV(base64.decode(parts[1]));
      final aes = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));

      return aes.decrypt(encrypt.Encrypted.fromBase64(data['cipherText']), iv: iv);
    } catch (e) {
      debugPrint("Decryption error: $e");
      return "[Decryption Failed]";
    }
  }

  // --- Helpers ---
  pc.AsymmetricKeyPair<pc.PublicKey, pc.PrivateKey> _generateRSAkeyPair() {
    final gen = pc.RSAKeyGenerator()..init(pc.ParametersWithRandom(pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64), _secureRandom()));
    return gen.generateKeyPair();
  }

  pc.SecureRandom _secureRandom() {
    final sr = pc.FortunaRandom();
    final r = Random.secure();
    sr.seed(pc.KeyParameter(Uint8List.fromList(List.generate(32, (_) => r.nextInt(256)))));
    return sr;
  }

  Uint8List _generateRandomBytes(int len) => Uint8List.fromList(List.generate(len, (_) => Random.secure().nextInt(256)));
}
