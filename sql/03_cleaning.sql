-- ============================================================
-- 03_cleaning.sql
-- Цель: убрать ошибки сплит-системы, неполные дни и дубли пользователей.
-- Результат: clean_ab_data (1 строка = 1 пользователь),
--            excluded_ab_data (реестр удалённых строк с причиной).
-- ============================================================

-- Шаг 1. Строки без несоответствия ab_group и landing_page
CREATE OR REPLACE TABLE valid_ab_data AS
SELECT user_id, event_ts, ab_group, landing_page, converted
FROM raw_ab_data
WHERE (ab_group = 'control'   AND landing_page = 'old_page')
   OR (ab_group = 'treatment' AND landing_page = 'new_page');

-- Шаг 2. Один пользователь = одна строка, берём первое взаимодействие.
CREATE OR REPLACE TABLE clean_ab_data AS
SELECT user_id, event_ts, ab_group, landing_page, converted
FROM valid_ab_data
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY user_id
    ORDER BY event_ts ASC, converted ASC
) = 1;

-- Шаг 3. Реестр исключённых строк
CREATE OR REPLACE TABLE excluded_ab_data AS
WITH mismatched AS (
    SELECT user_id, event_ts, ab_group, landing_page, converted,
           'group_landing_page_mismatch' AS exclusion_reason
    FROM raw_ab_data
    WHERE (ab_group = 'control'   AND landing_page = 'new_page')
       OR (ab_group = 'treatment' AND landing_page = 'old_page')
),
duplicated AS (
    SELECT user_id, event_ts, ab_group, landing_page, converted,
           'duplicate_valid_row' AS exclusion_reason
    FROM valid_ab_data
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY user_id ORDER BY event_ts ASC, converted ASC) > 1
)
SELECT * FROM mismatched
UNION ALL SELECT * FROM duplicated;

-- Шаг 5. Постусловия
-- P1: 1 строка на пользователя, несоответствий нет
SELECT
    COUNT(*)                        AS rows_total,
    COUNT(DISTINCT user_id)         AS users_total,
    COUNT(*) FILTER (
        WHERE (ab_group = 'control'   AND landing_page = 'new_page')
           OR (ab_group = 'treatment' AND landing_page = 'old_page')
    )                               AS mismatches
FROM clean_ab_data;

-- P2: ничего не потерялось
SELECT
    (SELECT COUNT(*) FROM clean_ab_data)
  + (SELECT COUNT(*) FROM excluded_ab_data)
  = (SELECT COUNT(*) FROM raw_ab_data) AS conservation_ok;

-- P3: сколько удалено и почему
SELECT exclusion_reason, COUNT(*) AS rows_dropped
FROM excluded_ab_data
GROUP BY exclusion_reason
ORDER BY rows_dropped DESC;