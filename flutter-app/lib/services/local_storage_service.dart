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
      version: 3,
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
            voiceUrl TEXT,
            status TEXT NOT NULL DEFAULT 'sent',
            deliveredAt TEXT,
            readAt TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY,
            phone TEXT NOT NULL,
            phoneMasked TEXT,
            nickname TEXT NOT NULL,
            avatar TEXT,
            createdAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_messages_users ON messages(senderId, receiverId)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE messages ADD COLUMN status TEXT NOT NULL DEFAULT 'sent'");
          await db.execute("ALTER TABLE messages ADD COLUMN deliveredAt TEXT");
          await db.execute("ALTER TABLE messages ADD COLUMN readAt TEXT");
        }
        if (oldVersion < 3) {
          await db.execute("DROP TABLE IF EXISTS users");
          await db.execute('''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY,
              phone TEXT NOT NULL,
              phoneMasked TEXT,
              nickname TEXT NOT NULL,
              avatar TEXT,
              createdAt TEXT NOT NULL
            )
          ''');
        }
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
        'voiceUrl': message.voiceUrl,
        'status': message.status.toString().split('.').last,
        'deliveredAt': message.deliveredAt?.toIso8601String(),
        'readAt': message.readAt?.toIso8601String(),
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
