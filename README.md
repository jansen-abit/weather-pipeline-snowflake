# NOAA Weather Pipeline — Snowflake

End-to-end data pipeline ingesting NOAA weather forecast data through a medallion architecture (RAW → CLEAN → SERVING) in Snowflake, with a published Snowsight dashboard.

**Portfolio Project 07 — Phase 1, Item 2**
[← Back to Portfolio](https://jansenabit.github.io)

---

## Architecture

```
Databricks Silver Layer (source)
        │
        ▼
   JSON Export
        │
        ▼
┌──────────────────────────────────────────┐
│              Snowflake                   │
│                                          │
│   Internal Stage (weather_stage)         │
│        │  COPY INTO                      │
│        ▼                                 │
│   RAW.weather_observations (VARIANT)     │
│        │  JSON flattening + type casting │
│        ▼                                 │
│   CLEAN.weather_clean (typed columns)    │
│        │  Aggregation                    │
│        ▼                                 │
│   SERVING.daily_city_summary             │
│        │                                 │
│        ▼                                 │
│   Snowsight Dashboard (3 tiles)          │
└──────────────────────────────────────────┘
```

## Data Source

NOAA Weather API (`api.weather.gov`) — 7-day forecasts for four US cities:
- Denver, CO
- Miami, FL
- New York, NY
- Seattle, WA

Data was originally ingested and transformed in Databricks (see [Phase 1 — Databricks](https://github.com/jansenabit/weather-pipeline-databricks)), then exported from the Silver layer as JSON and loaded into Snowflake via an internal stage.

> **Why export from Databricks instead of calling the API directly?**
> Snowflake trial accounts do not support External Access Integrations, which are required for outbound HTTP calls. This constraint led to a cross-platform data transfer pattern — a realistic scenario in production environments where teams migrate or replicate data between systems.

## Snowflake Objects

### Environment

| Object | Name | Purpose |
|--------|------|---------|
| Warehouse | `COMPUTE_WH` (X-Small) | Query compute |
| Database | `NOAA_DB` | All pipeline objects |
| Schema | `RAW` | Raw JSON landing zone |
| Schema | `CLEAN` | Flattened, typed columns |
| Schema | `SERVING` | Aggregated tables for dashboards |
| Stage | `RAW.WEATHER_STAGE` | Internal stage for JSON file uploads |

### Tables

**RAW.WEATHER_OBSERVATIONS** — Raw JSON landing table

| Column | Type | Description |
|--------|------|-------------|
| `id` | STRING | MD5 hash of raw JSON (dedup key) |
| `station_id` | STRING | City identifier |
| `timestamp_utc` | TIMESTAMP_NTZ | Forecast timestamp |
| `raw_json` | VARIANT | Full JSON payload |
| `ingested_at` | TIMESTAMP_NTZ | Load timestamp (auto-populated) |

**CLEAN.WEATHER_CLEAN** — Flattened and typed

| Column | Type | Description |
|--------|------|-------------|
| `id` | STRING | Row identifier |
| `city` | STRING | City name |
| `forecast_time` | TIMESTAMP_NTZ | Forecast timestamp |
| `temperature_f` | NUMBER(5,1) | Temperature in Fahrenheit |
| `temperature_c` | NUMBER(5,1) | Temperature in Celsius (derived) |
| `wind_speed_mph` | NUMBER(5,1) | Wind speed |
| `wind_direction` | STRING | Wind direction |
| `forecast_description` | STRING | Weather description |
| `precip_probability_pct` | NUMBER(5,1) | Precipitation probability |
| `is_daytime` | BOOLEAN | Daytime flag |
| `ingested_at` | TIMESTAMP_NTZ | Original ingestion timestamp |

**SERVING.DAILY_CITY_SUMMARY** — Daily aggregates

| Column | Type | Description |
|--------|------|-------------|
| `city` | STRING | City name |
| `forecast_date` | DATE | Forecast date |
| `avg_temp_f` | NUMBER | Average temperature (°F) |
| `avg_temp_c` | NUMBER | Average temperature (°C) |
| `min_temp_f` | NUMBER | Daily minimum (°F) |
| `max_temp_f` | NUMBER | Daily maximum (°F) |
| `avg_wind_speed_mph` | NUMBER | Average wind speed |
| `max_precip_pct` | NUMBER | Peak precipitation probability |
| `observation_count` | NUMBER | Forecasts per day |

## Pipeline Steps

### 1. Environment Setup
Created warehouse, database, schemas, roles, and grants. Snowflake objects are independent — the warehouse (compute) and database (storage) have no inherent relationship. Ordering in setup scripts is driven by GRANT dependencies, not object dependencies.

### 2. Ingestion
- Exported Databricks Silver table to JSON via Unity Catalog Volume
- Uploaded JSON to Snowflake internal stage (`PUT` via Snowsight UI)
- Loaded into RAW using `COPY INTO` with JSON parsing and MD5 hash generation

### 3. Transformation (CLEAN)
- Flattened VARIANT JSON into typed columns using Snowflake's semi-structured notation (`raw_json:field::TYPE`)
- Added derived Celsius column: `ROUND((temperature_f - 32) * 5/9, 1)`

### 4. Serving Layer
- Aggregated CLEAN data into daily city summaries (avg/min/max temps, wind, precipitation)
- 624 observation rows → 28 daily summary rows across 4 cities

### 5. Dashboard
Published Snowsight dashboard with three tiles:
- **Temperature Trend** — Line chart showing avg temperature by city over time
- **Rain Risk** — Bar chart showing max precipitation probability by city and date
- **Detail Table** — Full daily summary data

## Key Concepts Demonstrated

- **Medallion Architecture** in Snowflake (RAW → CLEAN → SERVING)
- **Semi-structured data handling** with VARIANT type and JSON path notation
- **Internal Stages** for file-based ingestion
- **COPY INTO** with inline transformations (MD5 hashing, type casting)
- **Cross-platform data movement** (Databricks → Snowflake)
- **Snowsight Dashboards** for data visualization

## Key Learnings

- **External Access Integrations are not available on trial accounts.** This blocks outbound HTTP from Snowflake, requiring an external ingestion pattern. In production, you'd use External Access to call APIs directly, or Snowpipe with cloud storage notifications.
- **Snowflake object independence.** Warehouses and databases are fully decoupled — unlike SQL Server where compute and storage are tightly bound. This separation enables elastic scaling and cost control.
- **Unity Catalog Volumes replaced DBFS.** Databricks is deprecating DBFS on Serverless Compute. Volumes provide the same file storage capability but with catalog-level governance, permissions, and lineage tracking.
- **Workspaces vs. Worksheets in Snowsight.** Workspaces are organizational folders; Worksheets are individual execution tabs. Legacy Worksheets and new Workspaces are separate systems — you can copy between them but not move.

## Row Counts

| Layer | Table | Rows |
|-------|-------|------|
| RAW | `weather_observations` | 624 |
| CLEAN | `weather_clean` | 624 |
| SERVING | `daily_city_summary` | 28 |

## Tech Stack

- **Snowflake** — Warehouse, Stages, VARIANT, Snowsight Dashboards
- **Databricks** — Source data (Silver layer export via Unity Catalog Volume)
- **NOAA Weather API** — Original data source
- **SQL** — All transformations and aggregations
- **Python (PySpark)** — Data export from Databricks

## Future Enhancements

- [ ] Streams & Tasks for automated CLEAN/SERVING refresh when RAW changes
- [ ] Snowpipe for continuous ingestion from cloud storage
- [ ] Dynamic Tables as an alternative to manual refresh
- [ ] Data quality checks and row-level access control (RBAC)
- [ ] Direct NOAA API ingestion (requires paid Snowflake account for External Access)
