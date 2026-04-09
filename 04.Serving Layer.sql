USE DATABASE NOAA_DB;
USE SCHEMA SERVING;

-- Daily summary aggregation
CREATE OR REPLACE TABLE daily_city_summary AS
SELECT
    city,
    DATE(forecast_time)                              AS forecast_date,
    ROUND(AVG(temperature_f), 1)                     AS avg_temp_f,
    ROUND(AVG(temperature_c), 1)                     AS avg_temp_c,
    MIN(temperature_f)                               AS min_temp_f,
    MAX(temperature_f)                               AS max_temp_f,
    ROUND(AVG(wind_speed_mph), 1)                    AS avg_wind_speed_mph,
    MAX(precip_probability_pct)                       AS max_precip_pct,
    COUNT(*)                                          AS observation_count
FROM CLEAN.weather_clean
GROUP BY city, DATE(forecast_time)
ORDER BY city, forecast_date;

-- Verify
SELECT COUNT(*) FROM daily_city_summary;
SELECT * FROM daily_city_summary LIMIT 10;