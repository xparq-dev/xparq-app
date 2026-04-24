import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xparq_app/features/auth/models/quick_account.dart';

class QuickAuthService extends ChangeNotifier {
  static const String _accountsKey = 'quick_accounts_v1';
  static const String _sessionPrefix = 'quick_session_';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  QuickAuthService(this._prefs, this._secureStorage);

  // ── Account List Management ──────────────────────────────────────────────

  List<QuickAccount> getQuickAccounts() {
    final jsonStr = _prefs.getString(_accountsKey);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> list = json.decode(jsonStr);
      return list.map((e) => QuickAccount.fromMap(e)).toList()
        ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    } catch (e) {
      return [];
    }
  }

  Future<void> saveQuickAccount(QuickAccount account) async {
    final accounts = getQuickAccounts();
    final index = accounts.indexWhere((a) => a.uid == account.uid);
    if (index != -1) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }
    await _prefs.setString(
      _accountsKey,
      json.encode(accounts.map((e) => e.toMap()).toList()),
    );
    notifyListeners();
  }

  Future<void> removeQuickAccount(String uid) async {
    final accounts = getQuickAccounts();
    accounts.removeWhere((a) => a.uid == uid);
    await _prefs.setString(
      _accountsKey,
      json.encode(accounts.map((e) => e.toMap()).toList()),
    );
    await _secureStorage.delete(key: '$_sessionPrefix$uid');
    notifyListeners();
  }

  // ── Session Security ───────────────────────────────────────────────

  Future<void> saveSession(
    String uid, {
    required String accessToken,
    required String refreshToken,
  }) async {
    final data = json.encode({
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    });
    await _secureStorage.write(key: '$_sessionPrefix$uid', value: data);
  }

  Future<void> clearSession(String uid) async {
    await _secureStorage.delete(key: '$_sessionPrefix$uid');
  }

  /// Returns a record of (accessToken, refreshToken) or null if not found.
  Future<({String accessToken, String refreshToken})?> getSession(
    String uid,
  ) async {
    final raw = await _secureStorage.read(key: '$_sessionPrefix$uid');
    if (raw == null) return null;
    try {
      final map = json.decode(raw) as Map<String, dynamic>;
      return (
        accessToken: map['accessToken'] as String,
        refreshToken: map['refreshToken'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _prefs.remove(_accountsKey);
    await _secureStorage.deleteAll();
  }
}
