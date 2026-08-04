# Slovakia Suppliers Enrichment, NACE Harmonization, and Proxy ESG Scoring Pipeline

A high-performance data engineering and proxy scoring pipeline built in **R**. This documentation outlines automated open-data ingestion; API multi-pass fuzzy matching against the Slovak Business Register (RPO) and the Register of Financial Statements (RÚZ); automated NACE code translation; and deterministic heuristic ESG proxy scoring for Slovak corporate entities.

---

## 🛑 Important Pre-Execution Notes
* **Manual Verification:** Ensure all open-data NACE codes are cross-verified and populated from official national registries (such as [Register Účtovných Jednotiek](https://www.registeruz.sk/) and the Statistical Office of the Slovak Republic) before secondary text extraction.
* **Variable Enforcement:** Target datasets must strictly adhere to the standardized schema (`str(df)`) prior to translation processing and score estimation.

---

## 📂 Repository Workflow & Pipeline Structure

The Slovakia enrichment and scoring pipeline executes sequentially across modular data engineering scripts, mirroring the architectural framework established in the Slovenian pilot:

1. **Multi-Pass Enterprise API Extraction** (`(2.2) v5 full company lookup.R`)**
   * Connects to the Slovak RPO API (`https://api.statistics.sk/rpo/v1/search`).
   * Executes a 5-pass search strategy (Exact Match, Cleaned Match, Transliterated Match, Brand Anchor Match, and Domain Keyword Match extracted from company websites).
   * Unpacks deep entity profiles including historical names, legal forms, statutory officers, shareholders, and municipalities using Jaro-Winkler string distance scoring.

2. **Raw Financial Register NACE Extraction (`(2.3) v5.1 nace grab.R`)**
   * Queries the RÚZ API (`https://www.registeruz.sk/cruz-public/api/uctovne-jednotky`) using standardized 8-digit IČO identifiers.
   * Extracts raw SK-NACE numerical codes and handles unstructured text or missing registry entries (e.g., "Neuvedené").

3. **NACE Rev. 2 Harmonization & Dictionary Mapping (`(2.4) v5.2 nace dictionary.R` and `(2.5) v5.3 nace translation layer.R`)**
   * Downloads and parses official Level 4 NACE Rev. 2 English classification data.
   * Converts raw numeric strings into standard 5-character Slovak formats (e.g., Letter + Division/Group/Class + 0, such as `K64.190`) via custom division-to-section mapping rules.
   * Performs non-destructive VLOOKUP-style dictionary joins to attach official English descriptions without disrupting dataset row order.

4. **Deterministic Heuristic Proxy ESG Scoring (`(2.6) v5.4 scoring.R`)**
   * Categorizes companies into **High-Impact**, **Medium-Impact**, or **Low-Impact** sectors, applying structural baseline adjustments (e.g., `-0.05` penalty for high-impact sectors like energy and heavy manufacturing).
   * Implements a deterministic seed (`set.seed(42)`) to assign baseline raw scores based on corporate profiling (Tier 1 Multinationals/Banks vs. Tier 2 SMEs/Local Entities).
   * Maps final scores to official classification brackets (*Sustainability Leader, Advanced, Progressing, Emerging, Limited, Insufficient*) and automatically assigns E/S/G priority pillars.

---

## 📊 Methodology Defense & Framework

For full details on the heuristic proxy scoring model, corporate profiling tiers, and sector impact penalties, refer to the accompanying core methodology documentation **(`(0) README Scoring Method.md`)**. 

The proxy model serves as an interim structural placeholder, providing immediate mathematical defensibility for pipeline testing and dashboard integration before integrating empirical third-party datasets (such as CDP, MSCI, or Sustainalytics).
