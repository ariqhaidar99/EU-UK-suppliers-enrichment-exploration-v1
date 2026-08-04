# ==========================================
# SK2 PROXY SCORING ADAPTATION SCRIPT
# ==========================================
# Install packages if you don't have them yet
install.packages(c("dplyr", "readr"))

# Load packages
library(dplyr)
library(readr)

# 1. Load the SK2 dataset
df_sk <- read_csv("CompiledCountries - SK2.csv", col_types = cols(.default = "character"))

# 2. Define Industry Impact and Baseline Adjustments
get_impact_and_adjustment <- function(nace_code, company_name) {
  nace <- as.character(nace_code)
  name <- tolower(as.character(company_name))
  
  # High-impact prefixes or keywords
  if (grepl("^(D35|C19|C20|C24|H50|H51)", nace) || 
      grepl("power|energy|gas|electric|oil|chemical|airline", name)) {
    return(list(impact = "High-Impact", adjustment = -0.05))
  } else if (grepl("^(K64|K65|K66|Q86|F|G|L|M|J|P|N|C|E|H)", nace)) {
    # Check specific high vs medium impact within manufacturing/utilities
    if (grepl("^(D35|C19|C20|C24)", nace)) {
      return(list(impact = "High-Impact", adjustment = -0.05))
    } else {
      return(list(impact = "Medium-Impact", adjustment = 0.00))
    }
  } else {
    return(list(impact = "Low-Impact", adjustment = 0.00))
  }
}

# Apply impact rules across rows
impacts <- character(nrow(df_sk))
adjustments <- numeric(nrow(df_sk))

for (i in 1:nrow(df_sk)) {
  res <- get_impact_and_adjustment(df_sk$nace_code[i], df_sk$company_name[i])
  impacts[i] <- res$impact
  adjustments[i] <- res$adjustment
}

df_sk$industry_impact     <- impacts
df_sk$baseline_adjustment <- adjustments

# 3. Define Priority Category Assignment (E/S/G)
assign_esg_priority <- function(company_name, industry_impact, nace_code) {
  name <- tolower(as.character(company_name))
  nace <- as.character(nace_code)
  
  if (grepl("bank|axa|aig|allianz|paypal|stripe|talanx|chubb|ey|schoenherr|legal|audit|consult", name)) {
    return("G")
  } else if (grepl("hospital|health|affidea|medical|pharma|care|staffing|kelly|manpower|experis", name)) {
    return("S")
  } else if (industry_impact == "High-Impact" || grepl("^(D|E|C)", nace)) {
    return("E")
  } else if (grepl("^(K|M)", nace)) {
    return("G")
  } else {
    return("G")
  }
}

df_sk$priority_category <- mapply(assign_esg_priority, df_sk$company_name, df_sk$industry_impact, df_sk$nace_code)

# 4. Estimate Heuristic Scores (with set.seed for reproducibility)
set.seed(42)

large_multinational_keywords <- c(
  'bank', 'allianz', 'axa', 'aig', 'bdo', 'generali', 'hofer', 'paypal', 'stripe', 
  'telekom', 't-mobile', 'revolut', 'smurfit', 'travelers', 'outfit7', 'ey', 'chubb',
  'talanx', 'lidl', 'billa', 'spp', 'seps', 'zsr', 'zalando', 'ikea', 'orange', 'vodafone',
  'slovenské elektrárne', 'slovenská pošta'
)

estimate_score <- function(name, company_id, baseline) {
  name_lower <- tolower(as.character(name))
  is_large <- any(sapply(large_multinational_keywords, function(kw) grepl(kw, name_lower))) || 
    (!is.na(company_id) && nchar(as.character(company_id)) <= 8)
  
  # Base raw score generation matching uniform distributions
  if (is_large) {
    raw_score <- round(runif(1, 0.65, 0.80), 2)
  } else {
    raw_score <- round(runif(1, 0.35, 0.55), 2)
  }
  
  # Apply baseline adjustment
  final_score <- raw_score + as.numeric(baseline)
  final_score <- round(max(0.0, min(1.0, final_score)), 2)
  
  # Classification mapping
  classification <- case_when(
    final_score >= 0.85 ~ "Sustainability Leader",
    final_score >= 0.70 ~ "Advanced",
    final_score >= 0.55 ~ "Progressing",
    final_score >= 0.40 ~ "Emerging",
    final_score >= 0.25 ~ "Limited",
    TRUE                ~ "Insufficient"
  )
  
  return(c(raw_score, final_score, classification))
}

scored_matrix <- t(mapply(estimate_score, df_sk$company_name, df_sk$company_id, df_sk$baseline_adjustment))

df_sk$estimated_raw_score      <- as.numeric(scored_matrix[, 1])
df_sk$estimated_final_score    <- as.numeric(scored_matrix[, 2])
df_sk$estimated_classification <- as.character(scored_matrix[, 3])

# 5. Export the Final Scored CSV
write_csv(df_sk, "CompiledCountries_SK2_FINAL_SCORED.csv")
print("Successfully scored SK2 and saved to CompiledCountries_SK2_FINAL_SCORED.csv!")
