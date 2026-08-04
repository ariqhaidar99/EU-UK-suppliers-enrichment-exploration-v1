# Slovenia Suppliers Enrichment and Exploration Pipeline

A high-performance data engineering and proxy scoring pipeline built in **R** and **PostgreSQL**. This repository automates open-data ingestion, database-backed fuzzy matching, automated NACE code translation, and deterministic heuristic ESG proxy scoring.

---

## 🛑 Important Pre-Execution Notes
* **Manual Verification:** Ensure all open-data NACE codes are cross-verified and populated from [Stop Neplačniki](https://www.stop-neplacniki.si/) before secondary text extraction.
* **Variable Enforcement:** Target datasets must strictly adhere to a 5-variable schema (`str(df)`) prior to translation processing.

---

## 📂 Repository Workflow Structure

The pipeline executes sequentially across three modular R scripts and relies on a structured proxy defense framework:

1. **Database-Backed Fuzzy Matching (`(1.2) v2 lookup SQL x R.R`)**
   * Ingests raw UTF-16 registry data (`opsiprs.csv`), normalizes it to UTF-8, and loads it into a local PostgreSQL instance.
   * Leverages the `pg_trgm` extension and **GIN trigram indexing** to perform high-speed fuzzy string matching against target company lists.

2. **NACE Translation & Extraction Layer (`(1.5) slovenian to english nace translation layer.R`)**
   * Extracts clean NACE codes (including sector letters) and description components.
   * Utilizes translation libraries to convert Slovenian business descriptions into English equivalents.

3. **Dictionary Mapping & Proxy Scoring Pipeline (`(1.7) v2 nace fill and scoring.R`)**
   * Resolves unlisted multinational entities ("phantom companies") via a pre-defined NACE dictionary map.
   * Calculates structural baseline adjustments based on sector impact and generates a deterministic heuristic ESG score and classification bracket using controlled random distributions (`set.seed(42)`).

---

## 📊 Methodology Defense & Framework

For full details regarding the heuristic proxy scoring model, corporate profiling tiers, and sector impact penalties, refer to the accompanying methodology documentation **(`(0) README Scoring Method.md`).** 

The proxy model serves as an interim structural placeholder, providing immediate mathematical defensibility for pipeline testing and dashboard integration before integrating empirical third-party datasets.
