import { Message } from '../types/chat';

const DB_NAME = 'MayMessengerDB';
const DB_VERSION = 1;
const MESSAGES_STORE = 'messages';
const OUTBOX_STORE = 'outbox';
const CHATS_STORE = 'chats';

export interface PendingMessage {
  localId: string;
  chatId: string;
  type: number;
  content?: string;
  localAudioPath?: string;
  syncState: 'localOnly' | 'syncing' | 'synced' | 'failed';
  createdAt: string;
  retryCount: number;
  errorMessage?: string;
  serverId?: string;
}

class IndexedDBStorage {
  private db: IDBDatabase | null = null;
  private initPromise: Promise<void> | null = null;

  async init(): Promise<void> {
    if (this.db) return;
    
    if (this.initPromise) {
      return this.initPromise;
    }

    this.initPromise = new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onerror = () => {
        console.error('[IndexedDB] Failed to open database:', request.error);
        reject(request.error);
      };

      request.onsuccess = () => {
        this.db = request.result;
        console.log('[IndexedDB] Database opened successfully');
        resolve();
      };

      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;

        // Messages cache store
        if (!db.objectStoreNames.contains(MESSAGES_STORE)) {
          const messagesStore = db.createObjectStore(MESSAGES_STORE, { keyPath: 'chatId' });
          messagesStore.createIndex('chatId', 'chatId', { unique: true });
          console.log('[IndexedDB] Created messages store');
        }

        // Outbox store for pending messages
        if (!db.objectStoreNames.contains(OUTBOX_STORE)) {
          const outboxStore = db.createObjectStore(OUTBOX_STORE, { keyPath: 'localId' });
          outboxStore.createIndex('chatId', 'chatId', { unique: false });
          outboxStore.createIndex('syncState', 'syncState', { unique: false });
          console.log('[IndexedDB] Created outbox store');
        }

        // Chats cache store
        if (!db.objectStoreNames.contains(CHATS_STORE)) {
          db.createObjectStore(CHATS_STORE, { keyPath: 'id' });
          console.log('[IndexedDB] Created chats store');
        }
      };
    });

    return this.initPromise;
  }

  private async ensureDB(): Promise<IDBDatabase> {
    if (!this.db) {
      await this.init();
    }
    if (!this.db) {
      throw new Error('Database not initialized');
    }
    return this.db;
  }

  // ==================== MESSAGES CACHE ====================

  async cacheMessages(chatId: string, messages: Message[]): Promise<void> {
    const db = await this.ensureDB();
    const transaction = db.transaction([MESSAGES_STORE], 'readwrite');
    const store = transaction.objectStore(MESSAGES_STORE);

    await new Promise<void>((resolve, reject) => {
      const request = store.put({
        chatId,
        messages,
        timestamp: new Date().toISOString(),
      });

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  async getCachedMessages(chatId: string): Promise<Message[] | null> {
    const db = await this.ensureDB();
    const transaction = db.transaction([MESSAGES_STORE], 'readonly');
    const store = transaction.objectStore(MESSAGES_STORE);

    return new Promise((resolve, reject) => {
      const request = store.get(chatId);

      request.onsuccess = () => {
        const result = request.result;
        resolve(result ? result.messages : null);
      };

      request.onerror = () => reject(request.error);
    });
  }

  async clearMessagesCache(): Promise<void> {
    const db = await this.ensureDB();
    const transaction = db.transaction([MESSAGES_STORE], 'readwrite');
    const store = transaction.objectStore(MESSAGES_STORE);

    await new Promise<void>((resolve, reject) => {
      const request = store.clear();
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  // ==================== OUTBOX (PENDING MESSAGES) ====================

  async addPendingMessage(message: PendingMessage): Promise<void> {
    const db = await this.ensureDB();
    const transaction = db.transaction([OUTBOX_STORE], 'readwrite');
    const store = transaction.objectStore(OUTBOX_STORE);

    await new Promise<void>((resolve, reject) => {
      const request = store.add(message);
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  async updatePendingMessage(message: PendingMessage): Promise<void> {
    const db = await this.ensureDB();
    const transaction = db.transaction([OUTBOX_STORE], 'readwrite');
    const store = transaction.objectStore(OUTBOX_STORE);

    await new Promise<void>((resolve, reject) => {
      const request = store.put(message);
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  async getPendingMessage(localId: string): Promise<PendingMessage | null> {
    const db = await this.ensureDB();
    const transaction = db.transaction([OUTBOX_STORE], 'readonly');
    const store = transaction.objectStore(OUTBOX_STORE);

    return new Promise((resolve, reject) => {
      const request = store.get(localId);
      request.onsuccess = () => resolve(request.result || null);
      request.onerror = () => reject(request.error);
    });
  }

  async getPendingMessagesForChat(chatId: string): Promise<PendingMessage[]> {
    const db = await this.ensureDB();
    const transaction = db.transaction([OUTBOX_STORE], 'readonly');
    const store = transaction.objectStore(OUTBOX_STORE);
    const index = store.index('chatId');

    return new Promise((resolve, reject) => {
      const request = index.getAll(chatId);
      request.onsuccess = () => {
        const messages = request.result || [];
        messages.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
        resolve(messages);
      };
      request.onerror = () => reject(request.error);
    });
  }

  async getAllPendingMessages(): Promise<PendingMessage[]> {
    const db = await this.ensureDB();
    const transaction = db.transaction([OUTBOX_STORE], 'readonly');
    const store = transaction.objectStore(OUTBOX_STORE);

    return new Promise((resolve, reject) => {
      const request = store.getAll();
      request.onsuccess = () => {
        const messages = request.result || [];
        messages.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
        resolve(messages);
      };
      request.onerror = () => reject(request.error);
    });
  }

  async removePendingMessage(localId: string): Promise<void> {
    const db = await this.ensureDB();
    const transaction = db.transaction([OUTBOX_STORE], 'readwrite');
    const store = transaction.objectStore(OUTBOX_STORE);

    await new Promise<void>((resolve, reject) => {
      const request = store.delete(localId);
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  async clearOutbox(): Promise<void> {
    const db = await this.ensureDB();
    const transaction = db.transaction([OUTBOX_STORE], 'readwrite');
    const store = transaction.objectStore(OUTBOX_STORE);

    await new Promise<void>((resolve, reject) => {
      const request = store.clear();
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  // ==================== CHATS CACHE ====================

  async cacheChats(chats: any[]): Promise<void> {
    const db = await this.ensureDB();
    const transaction = db.transaction([CHATS_STORE], 'readwrite');
    const store = transaction.objectStore(CHATS_STORE);

    // Clear existing chats
    await new Promise<void>((resolve, reject) => {
      const clearRequest = store.clear();
      clearRequest.onsuccess = () => resolve();
      clearRequest.onerror = () => reject(clearRequest.error);
    });

    // Add new chats
    for (const chat of chats) {
      await new Promise<void>((resolve, reject) => {
        const request = store.add(chat);
        request.onsuccess = () => resolve();
        request.onerror = () => reject(request.error);
      });
    }
  }

  async getCachedChats(): Promise<any[] | null> {
    const db = await this.ensureDB();
    const transaction = db.transaction([CHATS_STORE], 'readonly');
    const store = transaction.objectStore(CHATS_STORE);

    return new Promise((resolve, reject) => {
      const request = store.getAll();
      request.onsuccess = () => {
        const chats = request.result;
        resolve(chats.length > 0 ? chats : null);
      };
      request.onerror = () => reject(request.error);
    });
  }

  async clearChatsCache(): Promise<void> {
    const db = await this.ensureDB();
    const transaction = db.transaction([CHATS_STORE], 'readwrite');
    const store = transaction.objectStore(CHATS_STORE);

    await new Promise<void>((resolve, reject) => {
      const request = store.clear();
      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  // ==================== CLEAR ALL ====================

  async clearAll(): Promise<void> {
    await Promise.all([
      this.clearMessagesCache(),
      this.clearOutbox(),
      this.clearChatsCache(),
    ]);
  }
}

export const indexedDBStorage = new IndexedDBStorage();

