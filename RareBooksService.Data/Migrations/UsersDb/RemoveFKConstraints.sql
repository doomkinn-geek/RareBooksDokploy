-- Скрипт для удаления внешних ключей, которые ссылаются на RegularBaseBook
-- Эти FK некорректны, т.к. RegularBaseBook находится в другой базе данных (BooksDb)

-- Удаляем FK из UserCollectionBookMatches на RegularBaseBook
ALTER TABLE "UserCollectionBookMatches" 
DROP CONSTRAINT IF EXISTS "FK_UserCollectionBookMatches_RegularBaseBook_MatchedBookId";

-- Удаляем FK из UserCollectionBooks на RegularBaseBook  
ALTER TABLE "UserCollectionBooks"
DROP CONSTRAINT IF EXISTS "FK_UserCollectionBooks_RegularBaseBook_ReferenceBookId";

-- Удаляем таблицу RegularBaseBook и RegularBaseCategory, если они существуют
-- Эти таблицы были созданы по ошибке в UsersDb, но должны быть только в BooksDb
DROP TABLE IF EXISTS "RegularBaseBook" CASCADE;
DROP TABLE IF EXISTS "RegularBaseCategory" CASCADE;

-- Информация:
-- После выполнения этого скрипта:
-- 1. MatchedBookId и ReferenceBookId будут храниться как обычные int поля
-- 2. Валидация существования книги будет выполняться в коде через BooksDbContext
-- 3. Навигационные свойства MatchedBook и ReferenceBook игнорируются EF Core

