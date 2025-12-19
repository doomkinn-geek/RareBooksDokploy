declare module 'react-native-sqlite-storage' {
  export interface SQLiteDatabase {
    executeSql(sql: string, params?: any[]): Promise<[any]>;
    close(): Promise<void>;
  }

  export interface SQLite {
    DEBUG(debug: boolean): void;
    enablePromise(enable: boolean): void;
    openDatabase(params: {
      name: string;
      location?: string;
    }): Promise<SQLiteDatabase>;
  }

  const SQLite: SQLite;
  export default SQLite;
}

