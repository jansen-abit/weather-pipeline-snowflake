USE DATABASE NOAA_DB;
USE SCHEMA CLEAN;

-- Step 3a: Create the CLEAN table by flattening the raw JSON
CREATE OR REPLACE TABLE weather_clean AS
SELECT
    r.id,
    r.raw_json:city::STRING                          AS city,
    r.raw_json:forecast_time::TIMESTAMP_NTZ          AS forecast_time,
    r.raw_json:temperature_f::NUMBER(5,1)            AS temperature_f,
    ROUND((r.raw_json:temperature_f::FLOAT - 32) * 5/9, 1)  AS temperature_c,
    r.raw_json:wind_speed_mph::NUMBER(5,1)           AS wind_speed_mph,
    r.raw_json:wind_direction::STRING                AS wind_direction,
    r.raw_json:forecast_description::STRING          AS forecast_description,
    r.raw_json:precip_probability_pct::NUMBER(5,1)   AS precip_probability_pct,
    r.raw_json:is_daytime::BOOLEAN                   AS is_daytime,
    r.ingested_at
FROM RAW.weather_observations r;

-- Verify
SELECT COUNT(*) FROM weather_clean;
SELECT * FROM weather_clean LIMIT 5;