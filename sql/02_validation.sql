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

-- V3. Связаны ли дубли с ошибкой сплит-системы
WITH user_metrics AS (
    SELECT
        user_id,
        COUNT(*) AS row_count,
        COUNT(*) FILTER (
            WHERE (ab_group = 'control'   AND landing_page = 'new_page')
               OR (ab_group = 'treatment' AND landing_page = 'old_page')
        ) AS mismatch_count
    FROM raw_ab_data
    GROUP BY user_id
)
SELECT
    COUNT(*) FILTER (WHERE row_count > 1)                                  AS dup_users,
    COUNT(*) FILTER (WHERE row_count > 1 AND mismatch_count = 0)           AS dup_no_mismatch,
    COUNT(*) FILTER (WHERE row_count > 1 AND mismatch_count = row_count)   AS dup_all_mismatch,
    COUNT(*) FILTER (WHERE row_count > 1 AND mismatch_count BETWEEN 1 AND row_count - 1) AS dup_mixed
FROM user_metrics;

-- V4. Проверка на NULL-значения, их нет
-- V4a. Пропуски по каждой колонке
SELECT
    COUNT(*) FILTER (WHERE user_id      IS NULL) AS null_user_id,
    COUNT(*) FILTER (WHERE event_ts     IS NULL) AS null_event_ts,
    COUNT(*) FILTER (WHERE ab_group     IS NULL) AS null_group,
    COUNT(*) FILTER (WHERE landing_page IS NULL) AS null_landing_page,
    COUNT(*) FILTER (WHERE converted    IS NULL) AS null_converted
FROM raw_ab_data;

-- V4b. Домены значений
SELECT
    COUNT(*) FILTER (WHERE ab_group     NOT IN ('control', 'treatment'))   AS bad_group,
    COUNT(*) FILTER (WHERE landing_page NOT IN ('old_page', 'new_page'))   AS bad_page,
    COUNT(*) FILTER (WHERE converted    NOT IN (0, 1))                     AS bad_converted
FROM raw_ab_data;

-- V5. Проверка окна тестирования, похоже, что данные первого и последнего дней эксперимента обрезаны
-- V5a. Проверка продолжительности тестирования и подсчёт событий в день
SELECT
	MIN(event_ts) AS earliest_ts,
	MAX(event_ts) AS latest_ts,
	MAX(event_ts) - MIN(event_ts)
FROM raw_ab_data;

SELECT
	event_ts::DATE AS event_date,
	COUNT(*)       AS entries_per_day
FROM raw_ab_data
GROUP BY event_ts::DATE
ORDER BY event_date;

-- V5b. Соотношение первого и последнего дней к среднему полному дню
WITH daily_counts AS (
    SELECT
        event_ts::DATE AS event_date,
        COUNT(*) AS daily_rows,
        ROW_NUMBER() OVER (ORDER BY event_ts::DATE) AS day_num,
        COUNT(*) OVER () AS total_days
    FROM raw_ab_data
    GROUP BY event_ts::DATE
)
SELECT
    MAX(CASE WHEN day_num = 1 THEN daily_rows END) AS first_day_count,
    MAX(CASE WHEN day_num = total_days THEN daily_rows END) AS last_day_count,
    AVG(CASE WHEN day_num > 1 AND day_num < total_days THEN daily_rows END) AS avg_normal_day,
    ROUND(100.0 * MAX(CASE WHEN day_num = 1 THEN daily_rows END) / 
          AVG(CASE WHEN day_num > 1 AND day_num < total_days THEN daily_rows END), 1) AS first_day_pct,
    ROUND(100.0 * MAX(CASE WHEN day_num = total_days THEN daily_rows END) / 
          AVG(CASE WHEN day_num > 1 AND day_num < total_days THEN daily_rows END), 1) AS last_day_pct
FROM daily_counts;

-- V6. Покрытие соединения с countries в обе стороны
SELECT 'в ab_data нет в countries' AS check_name, COUNT(*) AS rows_found
FROM raw_ab_data ANTI JOIN raw_countries USING (user_id)
UNION ALL
SELECT 'в countries нет в ab_data', COUNT(*)
FROM raw_countries ANTI JOIN raw_ab_data USING (user_id);


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
GROUP BY event_ts::DATE
ORDER BY event_ts::DATE;

SELECT ROUND(AVG(converted) * 100.0, 2) AS total_cr
FROM raw_ab_data
