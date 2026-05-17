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
  })  : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ),
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

      final publicKeyString = _publicKeyToString(pub);

      await _storage.write(key: keyPath, value: privateKeyJson);
      await _syncPublicKeyToFirestore(user.uid, publicKeyString);
    } else {
      // ⚡ SELF-HEAL: Even if local keys are valid, verify they match what's on the server
      // This fixes "Decryption Failed" when switching between Debug/Deployed builds
      try {
        final Map<String, dynamic> keyMap = json.decode(jsonKeyData!);
        final priv = _parsePrivateKeyFromJson(keyMap);
        final pub = _derivePublicKey(priv);
        final localPubStr = _publicKeyToString(pub);
        
        // Fetch server key
        final nutDoc = await _firestore.collection('nutritionists').doc(user.uid).get();
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final serverPubStr = nutDoc.data()?['chatPublicKey'] ?? userDoc.data()?['chatPublicKey'];

        if (serverPubStr != localPubStr) {
          debugPrint("RSA Sync: Server key mismatch detected. Re-syncing...");
          await _syncPublicKeyToFirestore(user.uid, localPubStr);
        }
      } catch (e) {
        debugPrint("RSA Sync Verification failed: $e");
      }
    }
  }

  pc.RSAPrivateKey _parsePrivateKeyFromJson(Map<String, dynamic> map) {
    return pc.RSAPrivateKey(
      BigInt.parse(map['n']),
      BigInt.parse(map['d']),
      BigInt.parse(map['p']),
      BigInt.parse(map['q']),
      map['e'] != null ? BigInt.parse(map['e']) : BigInt.from(65537),
    );
  }

  pc.RSAPublicKey _parsePublicKeyFromString(String s) {
    final parts = s.split(":");
    return pc.RSAPublicKey(BigInt.parse(parts[0]), BigInt.parse(parts[1]));
  }

  pc.RSAPublicKey _derivePublicKey(pc.RSAPrivateKey priv) {
    return pc.RSAPublicKey(priv.n!, priv.publicExponent!);
  }

  String _publicKeyToString(pc.RSAPublicKey pub) {
    return "${pub.n}:${pub.publicExponent}";
  }

  Future<void> _syncPublicKeyToFirestore(String uid, String publicKeyString) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final nutRef = _firestore.collection('nutritionists').doc(uid);
      
      final uDoc = await userRef.get();
      if (uDoc.exists) {
        await userRef.update({'chatPublicKey': publicKeyString});
      }
      
      final nDoc = await nutRef.get();
      if (nDoc.exists) {
        await nutRef.update({'chatPublicKey': publicKeyString});
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

      // AES Logic
      final aesKeyBytes = _generateRandomBytes(32);
      final aesIVBytes = _generateRandomBytes(16);
      final aesEncrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(aesKeyBytes), mode: encrypt.AESMode.cbc));
      final encryptedMessage = aesEncrypter.encrypt(plaintext, iv: encrypt.IV(aesIVBytes));
      final keyPayload = base64.encode(aesKeyBytes) + "|" + base64.encode(aesIVBytes);

      // RSA Logic for recipient
      final rsaRecipient = encrypt.Encrypter(encrypt.RSA(publicKey: _parsePublicKeyFromString(recipientPubStr)));
      final encKeyRecipient = rsaRecipient.encrypt(keyPayload).base64;

      // RSA Logic for sender (self-decryption) - ALWAYS derive from local private key for 100% consistency
      String? encKeySender;
      try {
        final keyData = await _storage.read(key: '$_privateKeyPrefix${user.uid}');
        if (keyData != null && keyData.startsWith('{')) {
          final priv = _parsePrivateKeyFromJson(json.decode(keyData));
          final pub = _derivePublicKey(priv);
          final rsaSender = encrypt.Encrypter(encrypt.RSA(publicKey: pub));
          encKeySender = rsaSender.encrypt(keyPayload).base64;
        }
      } catch (e) {
        debugPrint("Local public key derivation failed: $e");
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
    if (data['isEncrypted'] != 'true') return data['cipherText'] ?? data['text'] ?? "";
    final user = _auth.currentUser;
    if (user == null) return "[Error: No User]";

    final msgSender = data['senderId'] ?? "unknown";
    final msgTime = data['timestamp'] != null ? data['timestamp'].toString() : "no-timestamp";

    try {
      final keyPath = '$_privateKeyPrefix${user.uid}';
      final keyData = await _storage.read(key: keyPath);
      if (keyData == null || !keyData.startsWith('{')) {
        debugPrint("E2EE decrypt: Local key v2 not found for ${user.uid}");
        return "[E2EE Setup Pending]";
      }

      final privKey = _parsePrivateKeyFromJson(json.decode(keyData));
      final rsa = encrypt.Encrypter(encrypt.RSA(privateKey: privKey));

      final targetKey = (data['senderId'] == user.uid) ? (data['senderEncryptedKey'] ?? data['encryptedKey']) : data['encryptedKey'];
      if (targetKey == null) {
        debugPrint("E2EE decrypt FAILED: targetKey is null for message from $msgSender at $msgTime");
        return "[Decryption Failed]";
      }

      final decryptedPayload = rsa.decrypt(encrypt.Encrypted.fromBase64(targetKey));
      
      final parts = decryptedPayload.split("|");
      final aesKey = encrypt.Key(base64.decode(parts[0]));
      final iv = encrypt.IV(base64.decode(parts[1]));
      final aes = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));

      final decryptedText = aes.decrypt(encrypt.Encrypted.fromBase64(data['cipherText']), iv: iv);
      debugPrint("E2EE decrypt SUCCESS: Decrypted message from $msgSender at $msgTime. Text: '$decryptedText'");
      return decryptedText;
    } catch (e) {
      debugPrint("E2EE decrypt FAILED: Error decrypting message from $msgSender at $msgTime. Error: $e");
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
