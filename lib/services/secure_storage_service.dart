import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  // Generic API Key management
  static const String _apiKeyKey = 'api_key';

  static Future<void> saveApiKey(String key) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: _apiKeyKey, value: key);
  }

  static Future<String?> getApiKey() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: _apiKeyKey);
  }

  // Picovoice API Key management
  static const String _picovoiceKeyKey = 'picovoice_access_key';

  static Future<void> savePicovoiceKey(String key) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: _picovoiceKeyKey, value: key);
  }

  static Future<String?> getPicovoiceKey() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: _picovoiceKeyKey);
  }

  static Future<void> deletePicovoiceKey() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: _picovoiceKeyKey);
  }

  // Instance methods
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
