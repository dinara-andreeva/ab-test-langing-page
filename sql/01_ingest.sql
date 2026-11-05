-- ============================================================
-- 01_ingest.sql
-- Цель: загрузить необработанные файлы.
-- Результат: таблицы DuckDB с сырыми данными.
-- ============================================================

CREATE OR REPLACE TABLE raw_ab_data AS
SELECT
    user_id,
    "timestamp"  AS event_ts, -- Переименовываем колонки синонимичные с зарезервированными
    "group"      AS ab_group,
    landing_page,
    converted
FROM read_csv(
    'data/ab_data.csv',
    header  = true,
    columns = {
        'user_id':      'BIGINT',
        'timestamp':    'TIMESTAMP',
        'group':        'VARCHAR',
        'landing_page': 'VARCHAR',
        'converted':    'INTEGER'
    }
);

CREATE OR REPLACE TABLE raw_countries AS
SELECT user_id, country
FROM read_csv(
    'data/countries.csv',
    header  = true,
    columns = {'user_id': 'BIGINT', 'country': 'VARCHAR'}
);