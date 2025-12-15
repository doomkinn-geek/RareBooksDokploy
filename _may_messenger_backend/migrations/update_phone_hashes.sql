-- Скрипт для пересоздания хешей номеров телефонов с нормализацией
-- Применяет ту же логику нормализации, что и PhoneNumberHelper.Normalize()

-- Функция для нормализации номера телефона (PostgreSQL)
CREATE OR REPLACE FUNCTION normalize_phone_number(phone_number TEXT)
RETURNS TEXT AS $$
DECLARE
    cleaned TEXT;
BEGIN
    IF phone_number IS NULL OR phone_number = '' THEN
        RETURN '';
    END IF;
    
    -- Удаляем все символы кроме цифр и +
    cleaned := regexp_replace(phone_number, '[^\d+]', '', 'g');
    
    -- Заменяем начальную 8 на +7 (для российских номеров)
    IF cleaned LIKE '8%' AND length(cleaned) = 11 THEN
        cleaned := '+7' || substring(cleaned from 2);
    END IF;
    
    -- Если номер начинается с 7 (без +), добавляем +
    IF cleaned LIKE '7%' AND length(cleaned) = 11 AND cleaned NOT LIKE '+%' THEN
        cleaned := '+' || cleaned;
    END IF;
    
    RETURN cleaned;
END;
$$ LANGUAGE plpgsql;

-- Обновляем хеши для всех пользователей
UPDATE "Users"
SET "PhoneNumberHash" = encode(sha256(normalize_phone_number("PhoneNumber")::bytea), 'hex');

-- Показываем результаты
SELECT 
    "Id",
    "PhoneNumber",
    normalize_phone_number("PhoneNumber") as normalized,
    "PhoneNumberHash" as new_hash
FROM "Users"
ORDER BY "PhoneNumber"
LIMIT 10;

-- Можно удалить функцию после использования
-- DROP FUNCTION IF EXISTS normalize_phone_number(TEXT);
