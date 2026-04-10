import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/user.dart';

class LocalStorageService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chat.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY,
            senderId INTEGER NOT NULL,
            receiverId INTEGER NOT NULL,
            content TEXT NOT NULL,
            type TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            isRead INTEGER NOT NULL,
            voiceUrl TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY,
            email TEXT NOT NULL,
            nickname TEXT NOT NULL,
            avatar TEXT,
            createdAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_messages_users ON messages(senderId, receiverId)
        ''');
      },
    );
  }

  // 消息相关
  Future<void> saveMessage(Message message) async {
    final db = await database;
    await db.insert(
      'messages',
      {
        'id': message.id,
        'senderId': message.senderId,
        'receiverId': message.receiverId,
        'content': message.content,
        'type': message.type.toString().split('.').last,
        'timestamp': message.timestamp.toIso8601String(),
        'isRead': message.isRead ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessages(String userId1, String userId2) async {
    final db = await database;
    final results = await db.query(
      'messages',
      where: '(senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)',
      whereArgs: [userId1, userId2, userId2, userId1],
      orderBy: 'timestamp ASC',
    );

    return results.map((json) => Message.fromJson(json)).toList();
  }

  Future<void> saveUser(User user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<User?> getUser(String userId) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (results.isEmpty) return null;
    return User.fromJson(results.first);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('users');
  }
}
