import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class SecureFileStorageService {
  static const String _keyStorageKey = 'secure_storage_key';
  static const String _fileName = 'conversations.enc';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  encrypt.Key? _encryptionKey;

  /// Initialize the service by loading or generating the encryption key
  Future<void> initialize() async {
    String? keyString = await _secureStorage.read(key: _keyStorageKey);

    if (keyString == null) {
      // Generate a new 32-byte (256-bit) key
      final key = encrypt.Key.fromSecureRandom(32);
      keyString = base64Url.encode(key.bytes);
      await _secureStorage.write(key: _keyStorageKey, value: keyString);
    }

    _encryptionKey = encrypt.Key(base64Url.decode(keyString));
  }

  /// Write data to encrypted file
  Future<void> write(String data) async {
    if (_encryptionKey == null) await initialize();

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');

    // Generate a random IV for each write
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey!));

    final encrypted = encrypter.encrypt(data, iv: iv);

    // Store IV + Encrypted Data
    // We prepend the IV to the file so we can read it back
    final combined = iv.bytes + encrypted.bytes;
    await file.writeAsBytes(combined);
  }

  /// Read data from encrypted file
  Future<String?> read() async {
    if (_encryptionKey == null) await initialize();

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');

    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    // Extract IV (first 16 bytes)
    final ivBytes = bytes.sublist(0, 16);
    final iv = encrypt.IV(ivBytes);

    // Extract Encrypted Data
    final encryptedBytes = bytes.sublist(16);
    final encrypted = encrypt.Encrypted(encryptedBytes);

    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey!));

    try {
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('Decryption error: $e');
      return null;
    }
  }

  /// Delete the storage file
  Future<void> delete() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
