USE DATABASE NOAA_DB;
-- Step 2a: Allow outbound calls to NOAA API
CREATE OR REPLACE NETWORK RULE noaa_api_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('api.weather.gov:443');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION noaa_api_access
  ALLOWED_NETWORK_RULES = (noaa_api_rule)
  ENABLED = TRUE;

-- Step 2b: Create the RAW landing table
USE SCHEMA NOAA_DB.RAW;

CREATE OR REPLACE TABLE weather_observations (
    id              STRING,
    station_id      STRING,
    timestamp_utc   TIMESTAMP_NTZ,
    raw_json        VARIANT,
    ingested_at     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

---------------------------------upload from databricks-------------
-- Create an internal stage in RAW schema
USE DATABASE NOAA_DB;
USE SCHEMA RAW;

CREATE OR REPLACE STAGE weather_stage
  FILE_FORMAT = (TYPE = 'JSON');


LIST @weather_stage;

------------------------------ copy data from uploded databricks json file-----------

COPY INTO weather_observations (id, station_id, timestamp_utc, raw_json)
FROM (
    SELECT
        MD5(TO_VARCHAR($1)),
        $1:city::STRING,
        $1:forecast_time::TIMESTAMP_NTZ,
        $1
    FROM @weather_stage/weather_silver_export.json
)
FILE_FORMAT = (TYPE = 'JSON', STRIP_OUTER_ARRAY = FALSE);


--- check data ---

SELECT COUNT(*) FROM weather_observations;
SELECT * FROM weather_observations LIMIT 5;