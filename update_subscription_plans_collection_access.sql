-- Скрипт для добавления доступа к коллекции для существующих планов подписки
-- Выполните этот скрипт в базе данных UsersDb

-- Обновляем все активные планы подписки, добавляя доступ к коллекции
UPDATE "SubscriptionPlans"
SET "HasCollectionAccess" = true
WHERE "IsActive" = true;

-- Проверяем результат
SELECT 
    "Id",
    "Name",
    "Price",
    "MonthlyRequestLimit",
    "IsActive",
    "HasCollectionAccess"
FROM "SubscriptionPlans"
ORDER BY "Id";

-- Если нужно обновить только конкретный план (например, Premium):
-- UPDATE "SubscriptionPlans"
-- SET "HasCollectionAccess" = true
-- WHERE "Name" = 'Premium' OR "Name" = 'Премиум';

-- Проверяем, что у пользователей обновились подписки
SELECT 
    u."UserName",
    u."Email",
    s."Id" as "SubscriptionId",
    s."IsActive",
    sp."Name" as "PlanName",
    sp."HasCollectionAccess"
FROM "AspNetUsers" u
LEFT JOIN "Subscriptions" s ON u."Id" = s."UserId"
LEFT JOIN "SubscriptionPlans" sp ON s."SubscriptionPlanId" = sp."Id"
WHERE s."IsActive" = true;

