# Proxy Scoring Methodology Defense (Slovenian Pilot)

## 1. Overview & Necessity
Due to a lack of immediate access to premium third-party ESG databases (e.g., MSCI, Sustainalytics) and the high resource cost of manually verifying hundreds of entities against open-source registries, a proxy scoring model was implemented. 
This model strictly substitutes empirical certification data with deterministic heuristics based on corporate size, EU regulatory compliance requirements, and sector-specific impact.

---

## 2. Algorithmic Proxy Application
The algorithm generates an estimated sustainability score (0.0 to 1.0) using a three-stage logic sequence:

### Stage A: Corporate Profiling & Base Raw Score Assignment
Entities are profiled based on their structural identity to estimate their likelihood of holding the certifications and reporting structures required by the overarching methodology.
* **Tier 1 (Multinationals, Financial Institutions, Major Tech):** Entities subject to strict EU ESG reporting mandates (CSRD/NFRD) or global compliance standards (e.g., Allianz, PayPal, Major Banks). These entities are statistically more likely to hold ISO 14001 and 45001 certifications and to have comprehensive ESG reporting. They are assigned a randomized base Raw Score between **0.65 and 0.80**.
* **Tier 2 (SMEs, Local Entities, Foreign Branches):** Entities that may lack resources for formal certifications despite good operational practices. They are assigned a randomized base Raw Score between **0.35 and 0.55**.

### Stage B: Industry Context & Baseline Adjustments
The exact NACE Rev. 2 sector codes generated for each entity are mapped to the framework's impact tiers:
* **High-Impact (Sector C, D, E, H51, etc.):** A definitive **-0.05 penalty** is applied to the Raw Score.
* **Medium-Impact & Low-Impact (Sectors K, M, J, etc.):** No penalty is applied (**0.00 adjustment**).

### Stage C: E/S/G Priority Assignment
In the absence of explicit certification ratios, the model defaults to standard industry sector alignment:
* **E (Environmental):** High-impact sectors, manufacturing, utilities.
* **S (Social):** Healthcare, retail, staffing.
* **G (Governance):** Financial services, professional services, tech.

---

## 3. Alignment with Scoring Scale
The calculated Final Score (`Raw Score + Adjustment`) is then rigidly mapped back to the standardized classification brackets:

| Score Range | Classification Bracket | Letter |
| :--- | :--- | :--- |
| **0.85 – 1.00** | Sustainability Leader | A |
| **0.70 – 0.84** | Advanced | B |
| **0.55 – 0.69** | Progressing | C | 
| **0.40 – 0.54** | Emerging | D |
| **0.25 – 0.39** | Limited | E |
| **0.00 – 0.24** | Insufficient | F |

---

## 4. Defensability & Future Integration
This heuristic approach acts as a structural placeholder. It creates a complete, mathematically sound dataset that enables immediate pipeline testing, dashboard building, and metric-weighting analysis. The model is designed to be instantly overridden once true data (e.g., API access to CDP or MSCI) is acquired, allowing a seamless transition from proxy data to empirical data without rebuilding the database architecture.
