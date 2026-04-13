import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OfflineChatDatabase {
  static final OfflineChatDatabase instance = OfflineChatDatabase._init();
  static Database? _database;

  OfflineChatDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('offline_chats.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String? docsPath;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      docsPath = docsDir.path;
    } catch (e) {
      debugPrint('[OfflineDB] path_provider failed in isolate: $e. Falling back to SharedPreferences...');
      try {
        final prefs = await SharedPreferences.getInstance();
        docsPath = prefs.getString('app_docs_path');
      } catch (pe) {
        debugPrint('[OfflineDB] SharedPreferences also failed: $pe');
      }
    }

    if (docsPath == null) {
      // LAST RESORT fallback: use sqflite's getDatabasesPath and guess
      final dbPath = await getDatabasesPath();
      docsPath = join(dbPath, '..', 'app_flutter'); 
      debugPrint('[OfflineDB] Using extreme fallback path: $docsPath');
    }

    final path = join(docsPath, filePath);
    debugPrint('[OfflineDB] Initializing database at: $path');

    return await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE offline_friends (
          peerId TEXT PRIMARY KEY,
          displayName TEXT NOT NULL,
          addedAt INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE offline_messages ADD COLUMN isRead INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      await _createSignalSessionsTable(db);
    }
    if (oldVersion < 5) {
      await _ensureSignalSessionColumns(db);
    }
    if (oldVersion < 6) {
      await _createSignalMessageCacheTable(db);
    }
    if (oldVersion < 7) {
      await _upgradeToMultiDeviceSessions(db);
    }
    if (oldVersion < 8) {
      await _upgradeToVanishingMessages(db);
    }
    if (oldVersion < 9) {
      await _createProfileCacheTable(db);
    }
    if (oldVersion < 10) {
      final hasCiphertext = await _hasColumn(
        db,
        tableName: 'signal_message_cache',
        columnName: 'ciphertext',
      );
      if (!hasCiphertext) {
        await db.execute(
          "ALTER TABLE signal_message_cache ADD COLUMN ciphertext TEXT NOT NULL DEFAULT ''",
        );
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE offline_messages (
  id $idType,
  peerId $textType,
  peerName $textType,
  message $textType,
  isMe $integerType,
  isRead $integerType DEFAULT 0,
  timestamp $integerType,
  expiresAt INTEGER
)
''');

    await db.execute('''
CREATE TABLE offline_friends (
  peerId TEXT PRIMARY KEY,
  displayName $textType,
  addedAt $integerType
)
''');

    await _createSignalSessionsTable(db);
    await _createSignalMessageCacheTable(db);
    await _createProfileCacheTable(db);
  }

  Future<void> _createProfileCacheTable(DatabaseExecutor db) async {
    await db.execute('''
    CREATE TABLE profile_cache (
      uid TEXT PRIMARY KEY,
      data_json TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''');
  }

  Future<void> _createSignalSessionsTable(DatabaseExecutor db) async {
    await db.execute('''
    CREATE TABLE signal_sessions (
      chatId TEXT,
      deviceId TEXT NOT NULL DEFAULT 'default',
      rootKey TEXT NOT NULL,
      sendingChainKey TEXT NOT NULL,
      receivingChainKey TEXT NOT NULL,
      sendingRatchetPrivateKey TEXT NOT NULL,
      sendingRatchetPublicKey TEXT NOT NULL DEFAULT '',
      receivingRatchetPublicKey TEXT NOT NULL,
      sendingIndex INTEGER NOT NULL DEFAULT 0,
      receivingIndex INTEGER NOT NULL DEFAULT 0,
      skippedMessageKeys TEXT NOT NULL DEFAULT '{}',
      PRIMARY KEY (chatId, deviceId)
    )
    ''');
  }

  Future<void> _upgradeToMultiDeviceSessions(Database db) async {
    // SQLite doesn't support easy ALTER PRIMARY KEY, so we recreate the table
    await db.transaction((txn) async {
      await txn.execute(
        'ALTER TABLE signal_sessions RENAME TO signal_sessions_old',
      );

      await _createSignalSessionsTable(txn);

      // Copy existing data, assuming 'default' device ID for old sessions
      await txn.execute('''
        INSERT INTO signal_sessions (
          chatId, deviceId, rootKey, sendingChainKey, receivingChainKey,
          sendingRatchetPrivateKey, sendingRatchetPublicKey, receivingRatchetPublicKey,
          sendingIndex, receivingIndex, skippedMessageKeys
        )
        SELECT 
          chatId, 'default', rootKey, sendingChainKey, receivingChainKey,
          sendingRatchetPrivateKey, sendingRatchetPublicKey, receivingRatchetPublicKey,
          sendingIndex, receivingIndex, skippedMessageKeys
        FROM signal_sessions_old
      ''');

      await txn.execute('DROP TABLE signal_sessions_old');
    });
  }

  Future<void> _upgradeToVanishingMessages(Database db) async {
    final hasExpiresAt = await _hasColumn(
      db,
      tableName: 'offline_messages',
      columnName: 'expiresAt',
    );
    if (!hasExpiresAt) {
      await db.execute(
        'ALTER TABLE offline_messages ADD COLUMN expiresAt INTEGER',
      );
    }
  }

  Future<void> _createSignalMessageCacheTable(DatabaseExecutor db) async {
    await db.execute('''
    CREATE TABLE signal_message_cache (
      messageId TEXT PRIMARY KEY,
      plaintext TEXT NOT NULL,
      ciphertext TEXT NOT NULL DEFAULT ''
    )
    ''');
  }

  Future<void> _ensureSignalSessionColumns(DatabaseExecutor db) async {
    final hasSendingRatchetPublicKey = await _hasColumn(
      db,
      tableName: 'signal_sessions',
      columnName: 'sendingRatchetPublicKey',
    );
    if (!hasSendingRatchetPublicKey) {
      await db.execute(
        "ALTER TABLE signal_sessions ADD COLUMN sendingRatchetPublicKey TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future<bool> _hasColumn(
    DatabaseExecutor db, {
    required String tableName,
    required String columnName,
  }) async {
    final rows = await db.rawQuery('PRAGMA table_info($tableName)');
    for (final row in rows) {
      if (row['name'] == columnName) return true;
    }
    return false;
  }

  Future<void> insertMessage({
    required String peerId,
    required String peerName,
    required String message,
    required bool isMe,
    DateTime? expiresAt,
  }) async {
    final db = await instance.database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await db.insert('offline_messages', {
      'peerId': peerId,
      'peerName': peerName,
      'message': message,
      'isMe': isMe ? 1 : 0,
      'isRead': isMe ? 1 : 0, // Outgoing messages are always "read"
      'timestamp': timestamp,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getMessages(String peerId) async {
    final db = await instance.database;

    return await db.query(
      'offline_messages',
      where: 'peerId = ?',
      whereArgs: [peerId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<int> getUnreadCount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM offline_messages WHERE isRead = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markAsRead(String peerId) async {
    final db = await instance.database;
    await db.update(
      'offline_messages',
      {'isRead': 1},
      where: 'peerId = ? AND isRead = 0',
      whereArgs: [peerId],
    );
  }

  Future<List<Map<String, dynamic>>> getRecentChats() async {
    final db = await instance.database;

    return await db.rawQuery('''
      SELECT peerId, peerName, MAX(timestamp) as lastMessageTime 
      FROM offline_messages 
      GROUP BY peerId 
      ORDER BY lastMessageTime DESC
    ''');
  }

  // Enforces the 3-day auto-purge rule
  Future<void> purgeOldMessages() async {
    final db = await instance.database;
    final threeDaysAgo = DateTime.now()
        .subtract(const Duration(days: 3))
        .millisecondsSinceEpoch;

    await db.delete(
      'offline_messages',
      where: 'timestamp < ?',
      whereArgs: [threeDaysAgo],
    );
  }

  Future<void> clearAllHistory() async {
    final db = await instance.database;
    await db.delete('offline_messages');
  }

  /// Deletes all local messages and Signal session state for a specific chat.
  Future<void> deleteChatLocally(String chatId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'offline_messages',
        where: 'peerId = ?',
        whereArgs: [chatId],
      );
      await txn.delete(
        'signal_sessions',
        where: 'chatId = ?',
        whereArgs: [chatId],
      );
      // plaintext cache is also chat-specific and should be cleared
      await txn.execute('''
        DELETE FROM signal_message_cache 
        WHERE messageId IN (
          SELECT id FROM offline_messages WHERE peerId = ?
        )
      ''', [chatId]);
    });
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('offline_messages');
      await txn.delete('offline_friends');
    });
  }

  Future<void> clearSignalSessions() async {
    final db = await instance.database;
    await db.delete('signal_sessions');
    await db.delete('signal_message_cache');
  }

  // --- SIGNAL MESSAGE CACHE ---

  Future<void> cacheSignalMessage(String messageId, String plaintext, String ciphertext) async {
    // SECURITY GUARD: Never cache placeholders or systemic error strings.
    if (plaintext.isEmpty || 
        plaintext.startsWith('🔒') || 
        plaintext == 'Encrypted message (Decryption Failed)') {
      return;
    }

    final db = await instance.database;
    await db.insert('signal_message_cache', {
      'messageId': messageId,
      'plaintext': plaintext,
      'ciphertext': ciphertext,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Removes a specific cached plaintext to force re-decryption.
  Future<void> removeSignalMessageCache(String messageId) async {
    final db = await instance.database;
    await db.delete(
      'signal_message_cache',
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
  }

  /// Wipes all cached plaintexts for a specific chat.
  /// Used for "Repair Discussion" to force re-decryption.
  Future<void> clearSignalMessageCacheByChatId(String chatId) async {
    final db = await instance.database;
    // We don't have chatId directly in signal_message_cache, 
    // but we can join with offline_messages.
    // Note: In our system, messageId is the same in both tables.
    await db.rawDelete('''
      DELETE FROM signal_message_cache 
      WHERE messageId IN (
        SELECT id FROM offline_messages WHERE peerId = ?
      )
    ''', [chatId]);
  }

  Future<Map<String, Map<String, String>>> getSignalMessageCache(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return {};
    final db = await instance.database;
    // Chunking to avoid SQL limits if list is too large
    final Map<String, Map<String, String>> results = {};
    for (var i = 0; i < messageIds.length; i += 100) {
      final chunk = messageIds.sublist(
        i,
        i + 100 > messageIds.length ? messageIds.length : i + 100,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.query(
        'signal_message_cache',
        where: 'messageId IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in rows) {
        results[row['messageId'] as String] = {
          'plaintext': row['plaintext'] as String,
          'ciphertext': row['ciphertext'] as String? ?? '',
        };
      }
    }
    return results;
  }

  // --- FRIENDSHIP MANAGEMENT ---

  Future<void> addFriend(String peerId, String displayName) async {
    final db = await instance.database;
    await db.insert('offline_friends', {
      'peerId': peerId,
      'displayName': displayName,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> isFriend(String peerId) async {
    final db = await instance.database;
    final result = await db.query(
      'offline_friends',
      where: 'peerId = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getFriends() async {
    final db = await instance.database;
    return await db.query('offline_friends', orderBy: 'addedAt DESC');
  }

  Future<void> removeFriend(String peerId) async {
    final db = await instance.database;
    await db.delete(
      'offline_friends',
      where: 'peerId = ?',
      whereArgs: [peerId],
    );
  }

  // --- PROFILE CACHE ---

  Future<void> upsertProfileCache(String uid, Map<String, dynamic> data) async {
    final db = await instance.database;
    final jsonStr = jsonEncode(data);
    await db.insert('profile_cache', {
      'uid': uid,
      'data_json': jsonStr,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getProfileCache(String uid) async {
    final db = await instance.database;
    final rows = await db.query(
      'profile_cache',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data_json'] as String)
        as Map<String, dynamic>;
  }

  Future<void> clearProfileCache({String? uid}) async {
    final db = await instance.database;
    if (uid == null) {
      await db.delete('profile_cache');
      return;
    }

    await db.delete(
      'profile_cache',
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  /// Exports Signal-related tables for backup.
  Future<Map<String, List<Map<String, dynamic>>>> exportSignalData() async {
    final db = await instance.database;
    final sessions = await db.query('signal_sessions');
    final cache = await db.query('signal_message_cache');
    return {'signal_sessions': sessions, 'signal_message_cache': cache};
  }

  /// Imports Signal-related tables from backup.
  Future<void> importSignalData(
    Map<String, List<Map<String, dynamic>>> data,
  ) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('signal_sessions');
      await txn.delete('signal_message_cache');

      if (data.containsKey('signal_sessions')) {
        for (final row in data['signal_sessions']!) {
          await txn.insert('signal_sessions', row);
        }
      }
      if (data.containsKey('signal_message_cache')) {
        for (final row in data['signal_message_cache']!) {
          await txn.insert('signal_message_cache', row);
        }
      }
    });
  }
}
