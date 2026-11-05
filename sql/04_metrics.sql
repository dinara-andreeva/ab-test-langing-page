-- ============================================================
-- 04_metrics.sql
-- Вход для ноутбука: SRM, основные метрики, динамика, страны.
-- ============================================================

-- M1. Размеры групп до и после очистки — вход для SRM-теста
SELECT 'raw' AS stage, ab_group, COUNT(*) AS n_users
FROM raw_ab_data GROUP BY ab_group
UNION ALL
SELECT 'clean', ab_group, COUNT(*)
FROM clean_ab_data GROUP BY ab_group
ORDER BY stage, ab_group;

-- M2. Основные метрики по группам
SELECT
    ab_group,
    COUNT(*)                        AS users,
    SUM(converted)                  AS conversions,
    ROUND(AVG(converted) * 100, 3)  AS cr_pct
FROM clean_ab_data
GROUP BY ab_group
ORDER BY ab_group;

-- M3. Конверсия по дням
SELECT
    event_ts::DATE AS event_date,
    ab_group,
    COUNT(*)                       AS users,
    SUM(converted)                 AS conversions,
    ROUND(AVG(converted) * 100, 3) AS cr_pct
FROM clean_ab_data
GROUP BY 1, 2
ORDER BY 1, 2;

-- M4. Кумулятивная конверсия (для графика и для анализа подглядывания)
WITH daily AS (
    SELECT event_ts::DATE AS event_date, ab_group,
           COUNT(*) AS users, SUM(converted) AS conversions
    FROM clean_ab_data
    GROUP BY 1, 2
)
SELECT
    event_date,
    ab_group,
    users,
    conversions,
    SUM(users)       OVER (PARTITION BY ab_group ORDER BY event_date) AS cum_users,
    SUM(conversions) OVER (PARTITION BY ab_group ORDER BY event_date) AS cum_conversions,
    ROUND(100.0
        * SUM(conversions) OVER (PARTITION BY ab_group ORDER BY event_date)
        / SUM(users)       OVER (PARTITION BY ab_group ORDER BY event_date), 3) AS cum_cr_pct
FROM daily
ORDER BY event_date, ab_group;

-- M5. Конверсия по странам (исследовательский разрез)
SELECT
    c.country,
    a.ab_group,
    COUNT(*)                       AS users,
    SUM(a.converted)               AS conversions,
    ROUND(AVG(a.converted) * 100, 3) AS cr_pct
FROM clean_ab_data a
JOIN raw_countries c USING (user_id)
GROUP BY 1, 2
ORDER BY 1, 2;

-- M6. Покрытие стран после очистки — проверка перед разрезом M5
SELECT 'clean без страновой записи' AS check_name, COUNT(*) AS rows_found
FROM clean_ab_data ANTI JOIN raw_countries USING (user_id)
UNION ALL
SELECT 'страны вне clean', COUNT(*)
FROM raw_countries ANTI JOIN clean_ab_data USING (user_id);