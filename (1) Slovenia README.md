# Slovenian Business Registry Matching & NACE Translation Pipeline

A high-performance, database-backed ETL and text processing pipeline built in **R** and **PostgreSQL**. This pipeline handles raw open-data ingestion, database indexing, entity matching, and automated multi-language NACE code translation.

---

## 🛑 Important Pre-Execution Instructions
* **README 1:** Before running the workflow, please ensure all NACE codes are manually verified and filled from [Stop Neplačniki](https://www.stop-neplacniki.si/).
* **README 2:** Please ensure that there are strictly **only 5 variables** when checking the structure via `str(df)` on the input dataset.

---

## 🚀 Architecture Overview
1. **ETL Ingestion & Normalization:** Parses raw UTF-16 encoded European open-data files (`opsiprs.csv`), converts them to UTF-8, and normalizes headers for database compatibility.
2. **Database Indexing:** Loads registry records into a local PostgreSQL instance and builds a **Generalized Inverted Index (`GIN`)** using the `pg_trgm` (trigram) extension.
3. **Execution & Translation:** Queries the database for matched company records, cleans target names, extracts precise NACE classifications, and translates Slovenian descriptions into English via translation packages.

---

## 🛠️ Prerequisites & Setup

### 1. Requirements
* **R** (with packages: `data.table`, `DBI`, `RPostgres`, `stringr`, `polyglotr`)
* **PostgreSQL** installed and running locally

### 2. Required Input Files
* `opsiprs.csv` — Raw Slovenian Business Register dataset from the [EU Open Data Portal](https://data.europa.eu/data/datasets/poslovni-register-slovenije?locale=en) (strip all columns except registration ID and company name using Excel/LibreOffice for optimization).
* `CompiledCountries - SL (reset.csv)` — Target list of companies to match.
* `CompiledCountries - SL (fixed2.csv)` — Prepared dataset for secondary NACE code parsing and translation processing.

---

## 💻 Usage Instructions

1. Open your PostgreSQL instance and create a blank database:
   ```sql
   CREATE DATABASE slovenia_db2;
