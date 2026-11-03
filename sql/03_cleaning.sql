-- ============================================================
-- 03_cleaning.sql
-- Цель: убрать ошибки сплит-системы и дубли пользователей.
-- Результат: таблица clean_ab_data (1 строка = 1 пользователь).
-- ============================================================

CREATE OR REPLACE TABLE clean_ab_data AS
WITH ranked_data AS (
    SELECT 
        user_id,
        timestamp,
        "group",
        landing_page,
        converted,
        ROW_NUMBER() OVER (
        PARTITION BY user_id
        ORDER BY timestamp ASC) AS rn
    FROM raw_ab_data
    WHERE ("group" = 'control' AND landing_page = 'old_page') OR ("group" = 'treatment' AND landing_page = 'new_page')
)
SELECT 
    user_id,
    timestamp,
    "group",
    landing_page,
    converted
FROM ranked_data
WHERE rn = 1; -- Оставляем только первое (уникальное) взаимодействие