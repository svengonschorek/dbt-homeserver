# dbt-homeserver

A cryptocurrency trading analytics data warehouse built with dbt and ClickHouse. Integrates data from Binance and Bybit to provide unified portfolio tracking, transaction history, and PnL analytics using a [Data Vault 2.0](https://www.datavaultalliance.com/) architecture.

## Architecture

The project implements three layers following Data Vault 2.0 methodology:

```
Source Data (Binance, Bybit)
        │
        ▼
┌─────────────────────────────────────────────────┐
│  Vault Raw  (vault_raw)                         │
│  Hubs · Satellites · Links                      │
└─────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────┐
│  Vault Business  (vault_business)               │
│  Derived calculations and business logic        │
└─────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────┐
│  Mart Core  (mart_core)                         │
│  Fact tables for analytics and reporting        │
└─────────────────────────────────────────────────┘
```

## Tech Stack

| Tool | Version |
|------|---------|
| dbt-core | 1.8.3 |
| dbt-clickhouse | 1.8.1 |
| ClickHouse | — |
| sqlfluff | 3.1.0 |

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Access to the ClickHouse instance at `192.168.178.32:8123`
- dbt credentials configured

### Setup

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd dbt-homeserver
   ```

2. Copy and fill in the environment config:
   ```bash
   cp config/.env.example config/.env
   ```

3. Run via Docker:
   ```bash
   docker-compose up
   ```

   Or install dependencies locally or in a virtual environment and configure a `profiles.yml` pointing to your ClickHouse instance.

### Running dbt

```bash
# Install dependencies
dbt deps

# Run all models
dbt run

# Run a specific layer
dbt run --select vault.raw
dbt run --select vault.business
dbt run --select mart.core

# Run tests
dbt test

# Generate and serve docs
dbt docs generate
dbt docs serve
```

## Design Decisions

- **ClickHouse types:** Financial amounts use `Decimal64`/`Decimal32` to avoid floating-point precision loss.
- **Timezones:** All datetime conversions use `Europe/Berlin`.
- **Deduplication:** Row-number windowing handles duplicate records from source exports.
- **Data lineage:** Every row carries `record_source` (dbt invocation ID) and `load_dts` for auditability.
