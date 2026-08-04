# Slovakia Suppliers Enrichment, NACE Harmonization, and Proxy ESG Scoring Pipeline

A high-performance data engineering and proxy scoring pipeline built in **R**[cite: 4, 5, 6, 7, 8]. This documentation outlines the automated open-data ingestion, API multi-pass fuzzy matching against the Slovak Business Register (RPO) and Register of Financial Statements (RÚZ), automated NACE code translation, and deterministic heuristic ESG proxy scoring for Slovak corporate entities.

---

## 🛑 Important Pre-Execution Notes
* **Manual Verification:** Ensure all open-data NACE codes are cross-verified and populated from official national registries (such as [Register Účtovných Jednotiek](https://www.registeruz.sk/) and the Statistical Office of the Slovak Republic) before secondary text extraction[cite: 5].
* **Variable Enforcement:** Target datasets must strictly adhere to the standardized schema (`str(df)`) prior to translation processing and score estimation.

---

## 📂 Repository Workflow & Pipeline Structure

The Slovakia enrichment and scoring pipeline executes sequentially across modular data engineering scripts, mirroring the architectural framework established in the Slovenian pilot[cite: 9]:

1. **Multi-Pass Enterprise API Extraction (`SK_pipeline_part1.R` based on[cite: 4])**
   * Connects to the Slovak RPO API (`https://api.statistics.sk/rpo/v1/search`)[cite: 4].
   * Executes a 5-pass search strategy (Exact Match, Cleaned Match, Transliterated Match, Brand Anchor Match, and Domain Keyword Match extracted from company websites)[cite: 4].
   * Unpacks deep entity profiles including historical names, legal forms, statutory officers, shareholders, and municipalities using Jaro-Winkler string distance scoring[cite: 4].

2. **Raw Financial Register NACE Extraction (`SK_pipeline_part2.R` based on[cite: 5])**
   * Queries the RÚZ API (`https://www.registeruz.sk/cruz-public/api/uctovne-jednotky`) using standardized 8-digit IČO identifiers[cite: 5].
   * Extracts raw SK-NACE numerical codes and handles unstructured text or missing registry entries (e.g., "Neuvedené")[cite: 5].

3. **NACE Rev. 2 Harmonization & Dictionary Mapping (`SK_pipeline_part3.R` based on[cite: 6, 7])**
   * Downloads and parses official Level 4 NACE Rev. 2 English classification data[cite: 6].
   * Converts raw numeric strings into standard 5-character Slovak formats (e.g., Letter + Division/Group/Class + 0, such as `K64.190`) via custom division-to-section mapping rules[cite: 6, 7].
   * Performs non-destructive VLOOKUP-style dictionary joins to attach official English descriptions without disrupting dataset row order[cite: 7].

4. **Deterministic Heuristic Proxy ESG Scoring (`SK_pipeline_part4.R` based on[cite: 8])**
   * Categorizes companies into **High-Impact**, **Medium-Impact**, or **Low-Impact** sectors, applying structural baseline adjustments (e.g., `-0.05` penalty for high-impact sectors like energy and heavy manufacturing)[cite: 1, 8].
   * Implements a deterministic seed (`set.seed(42)`) to assign baseline raw scores based on corporate profiling (Tier 1 Multinationals/Banks vs. Tier 2 SMEs/Local Entities)[cite: 2, 8].
   * Maps final scores to official classification brackets (*Sustainability Leader, Advanced, Progressing, Emerging, Limited, Insufficient*) and automatically assigns E/S/G priority pillars[cite: 1, 2, 8].

---

## 📊 Methodology Defense & Framework

For full details regarding the heuristic proxy scoring model, corporate profiling tiers, and sector impact penalties, refer to the accompanying core methodology documentation **(`(puja) 1. Individual Scoring Methodology.pdf`)** and proxy defense overview **(`Slovenia_Proxy_Scoring_Defense_Methodology.md`)**[cite: 1, 2]. 

The proxy model serves as an interim structural placeholder, providing immediate mathematical defensibility for pipeline testing and dashboard integration before integrating empirical third-party datasets (such as CDP, MSCI, or Sustainalytics)[cite: 2].
