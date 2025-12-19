import SQLite, { SQLiteDatabase } from 'react-native-sqlite-storage';
import { Message } from '../types';

// @ts-ignore - No types available for react-native-sqlite-storage
SQLite.DEBUG(true);
SQLite.enablePromise(true);

class SQLiteService {
  private db: SQLiteDatabase | null = null;

  async init(): Promise<void> {
    try {
      this.db = await SQLite.openDatabase({
        name: 'depesha.db',
        location: 'default',
      });
      
      await this.createTables();
      console.log('[SQLite] Database initialized');
    } catch (error) {
      console.error('[SQLite] Init error:', error);
      throw error;
    }
  }

  private async createTables(): Promise<void> {
    if (!this.db) return;

    const createMessagesTable = `
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        chatId TEXT NOT NULL,
        senderId TEXT NOT NULL,
        senderName TEXT NOT NULL,
        type INTEGER NOT NULL,
        content TEXT,
        filePath TEXT,
        localAudioPath TEXT,
        localImagePath TEXT,
        status INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        localId TEXT,
        isLocalOnly INTEGER DEFAULT 0,
        syncedAt TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_messages_chatId ON messages(chatId);
      CREATE INDEX IF NOT EXISTS idx_messages_createdAt ON messages(createdAt);
    `;

    try {
      await this.db.executeSql(createMessagesTable);
      console.log('[SQLite] Tables created');
    } catch (error) {
      console.error('[SQLite] Create tables error:', error);
    }
  }

  async cacheMessage(message: Message): Promise<void> {
    if (!this.db) return;

    try {
      await this.db.executeSql(
        `INSERT OR REPLACE INTO messages 
        (id, chatId, senderId, senderName, type, content, filePath, localAudioPath, localImagePath, status, createdAt, localId, isLocalOnly, syncedAt)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          message.id,
          message.chatId,
          message.senderId,
          message.senderName,
          message.type,
          message.content || null,
          message.filePath || null,
          message.localAudioPath || null,
          message.localImagePath || null,
          message.status,
          message.createdAt,
          message.localId || null,
          message.isLocalOnly ? 1 : 0,
          new Date().toISOString(),
        ]
      );
    } catch (error) {
      console.error('[SQLite] Cache message error:', error);
    }
  }

  async getCachedMessages(chatId: string, limit: number = 50): Promise<Message[]> {
    if (!this.db) return [];

    try {
      const [results] = await this.db.executeSql(
        `SELECT * FROM messages 
         WHERE chatId = ? 
         ORDER BY createdAt DESC 
         LIMIT ?`,
        [chatId, limit]
      );

      const messages: Message[] = [];
      for (let i = 0; i < results.rows.length; i++) {
        const row = results.rows.item(i);
        messages.push({
          id: row.id,
          chatId: row.chatId,
          senderId: row.senderId,
          senderName: row.senderName,
          type: row.type,
          content: row.content,
          filePath: row.filePath,
          localAudioPath: row.localAudioPath,
          localImagePath: row.localImagePath,
          status: row.status,
          createdAt: row.createdAt,
          localId: row.localId,
          isLocalOnly: row.isLocalOnly === 1,
        });
      }

      return messages.reverse();
    } catch (error) {
      console.error('[SQLite] Get cached messages error:', error);
      return [];
    }
  }

  async clearChatCache(chatId: string): Promise<void> {
    if (!this.db) return;

    try {
      await this.db.executeSql('DELETE FROM messages WHERE chatId = ?', [chatId]);
    } catch (error) {
      console.error('[SQLite] Clear chat cache error:', error);
    }
  }

  async close(): Promise<void> {
    if (this.db) {
      await this.db.close();
      this.db = null;
      console.log('[SQLite] Database closed');
    }
  }
}

export const sqliteService = new SQLiteService();

