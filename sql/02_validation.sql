-- ============================================================
-- 02_validation.sql
-- Цель: проанализировать чистоту и корректность данных.
-- Результат: близкое рассмотрение данных и числовые значения параметров.
-- ============================================================

-- V1. Объём данных: строки, уникальные пользователи, дубли
SELECT
    COUNT(*)                            AS rows_total,
    COUNT(DISTINCT user_id)             AS users_total,
    COUNT(*) - COUNT(DISTINCT user_id)  AS duplicate_rows
FROM raw_ab_data;

-- V2. Перекрёстная таблица group x landing_page, проверка работы сплит-системы
SELECT
    ab_group,
    landing_page,
    COUNT(*) AS users
FROM raw_ab_data
GROUP BY ab_group, landing_page
ORDER BY ab_group, landing_page;

-- V3. Дупликация сопровождается несоответствием колонок control/treatment и old_page/new_page в 3893 из 3894 случаев
WITH user_dupes AS (
	SELECT user_id
	FROM raw_ab_data
	GROUP BY user_id
	HAVING COUNT(*) > 1
	LIMIT 20
)
SELECT *
FROM raw_ab_data
WHERE user_id IN (SELECT user_id FROM user_dupes)
ORDER BY user_id;

WITH user_metrics AS (
    SELECT 
        user_id,
        COUNT(*) AS row_count,
        SUM(CASE 
            WHEN (ab_group = 'treatment' AND landing_page = 'old_page') OR 
                 (ab_group = 'control' AND landing_page = 'new_page') 
            THEN 1 
            ELSE 0 
        END) AS mismatch_count
    FROM raw_ab_data
    GROUP BY user_id
)
SELECT 
    COUNT(CASE WHEN row_count > 1 THEN 1 END) AS total_duplicated_users,
    COUNT(CASE WHEN row_count > 1 AND mismatch_count > 0 THEN 1 END) AS duplicated_with_mismatch,
FROM user_metrics;

-- V4. Проверка на NULL-значения, их нет
SELECT * AS null_values
FROM raw_ab_data
WHERE COLUMNS(*) IS NULL;

-- V5. Проверка окна тестирования, похоже, что данные первого и последнего дней эксперимента обрезаны
SELECT
	MIN(event_ts) AS earliest_ts,
	MAX(event_ts) AS latest_ts
FROM raw_ab_data;

SELECT
	event_ts::DATE AS event_date,
	COUNT(*)       AS entries_per_day
FROM raw_ab_data
GROUP BY event_ts::DATE;

-- V6. Покрытие соединения получилось 100%
SELECT * AS join_leakage
FROM raw_ab_data
ANTI JOIN raw_countries
USING (user_id)

UNION ALL

SELECT *
FROM raw_countries
ANTI JOIN raw_ab_data
USING (user_id);

-- V7. Подсчёт данных с несоответствием групп, процент экспериментальной группы и конверсии по дням и коэффициент конверсии по всем данным
SELECT COUNT(*) AS control_new_count
FROM raw_ab_data
WHERE ab_group = 'control' AND landing_page = 'new_page';

SELECT COUNT(*) AS treatment_old_count
FROM raw_ab_data
WHERE ab_group = 'treatment' AND landing_page = 'old_page';

SELECT
	event_ts::DATE AS event_date,
	ROUND(
		AVG(
			CASE WHEN ab_group = 'treatment' THEN 100.0
				 WHEN ab_group = 'control'   THEN 0.0 END
		), 2
	) AS treatment_share,
	AVG(converted) AS conversion_rate
FROM raw_ab_data
GROUP BY event_ts::DATE;

SELECT ROUND(AVG(converted) * 100.0, 2) AS total_cr
FROM raw_ab_data
