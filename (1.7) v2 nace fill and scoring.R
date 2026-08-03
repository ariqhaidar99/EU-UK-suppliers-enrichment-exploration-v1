# install.packages(c("dplyr", "readr"))
library(dplyr)
library(readr)

# 1. Load your dataset
df <- read_csv("CompiledCountries_SL_FINAL_COMPLETE.csv", col_types = cols(.default = "character"))
# or whatever the file name is

# 2. Define the exact NACE lookup dictionary list (with standard sector letters)
nace_map <- list(
  'ÅF Pöyry Slovenia'                 = c('M71.120', 'Engineering activities and related technical consultancy'),
  'Affidea Slovenia'                  = c('Q86.900', 'Other human health activities'),
  'Afry Slovenia'                     = c('M71.120', 'Engineering activities and related technical consultancy'),
  'AIG Slovenia'                      = c('K65.120', 'Non-life insurance'),
  'Akkodis Slovenia'                  = c('N78.200', 'Temporary employment agency activities'),
  'AXA Partners Slovenia'             = c('K65.120', 'Non-life insurance'),
  'Bravida Slovenia'                  = c('F43.210', 'Electrical installation'),
  'Brunel Slovenia'                   = c('N78.200', 'Temporary employment agency activities'),
  'Bunq Slovenia'                     = c('K64.190', 'Other monetary intermediation'),
  'Caverion Slovenia'                 = c('F43.210', 'Electrical installation'),
  'COWI Slovenia'                     = c('M71.120', 'Engineering activities and related technical consultancy'),
  'eToro Slovenia'                    = c('K64.990', 'Other financial service activities, except insurance and pension funding n.e.c.'),
  'Etteplan Slovenia'                 = c('M71.120', 'Engineering activities and related technical consultancy'),
  'EVBox Slovenia'                    = c('C27.120', 'Manufacture of electricity distribution and control apparatus'),
  'Gi Group Slovenia'                 = c('N78.200', 'Temporary employment agency activities'),
  'Grafton Recruitment Slovenia'      = c('N78.200', 'Temporary employment agency activities'),
  'Honeywell Safety Products Slovenia'= c('C32.990', 'Other manufacturing n.e.c.'),
  'Kelly Services Slovenia'           = c('N78.200', 'Temporary employment agency activities'),
  'Modis Slovenia'                    = c('N78.200', 'Temporary employment agency activities'),
  'Multiconsult Slovenia'             = c('M71.120', 'Engineering activities and related technical consultancy'),
  'Newsec Slovenia'                   = c('L68.310', 'Real estate agencies'),
  'Norconsult Slovenia'              = c('M71.120', 'Engineering activities and related technical consultancy'),
  'Outfit7'                           = c('J62.010', 'Computer programming activities'),
  'PayPal Slovenia'                   = c('K64.990', 'Other financial service activities, except insurance and pension funding n.e.c.'),
  'Pöyry Slovenia'                    = c('M71.120', 'Engineering activities and related technical consultancy'),
  'Rejlers Slovenia'                  = c('M71.120', 'Engineering activities and related technical consultancy'),
  'Semcon Slovenia'                   = c('M71.120', 'Engineering activities and related technical consultancy'),
  'Smurfit Kappa Slovenia'            = c('C17.210', 'Manufacture of corrugated paper and paperboard'),
  'Spring Professional Slovenia'      = c('N78.200', 'Temporary employment agency activities'),
  'Starr Insurance Slovenia'          = c('K65.120', 'Non-life insurance'),
  'Stripe Slovenia'                   = c('K64.990', 'Other financial service activities, except insurance and pension funding n.e.c.'),
  'Synergie Slovenia'                 = c('N78.200', 'Temporary employment agency activities'),
  'Synlab Slovenia'                   = c('Q86.900', 'Other human health activities'),
  'T-Mobile Slovenia'                 = c('J61.200', 'Wireless telecommunications activities'),
  'Talanx Slovenia'                   = c('K65.120', 'Non-life insurance'),
  'Tide Slovenia'                     = c('K64.990', 'Other financial service activities, except insurance and pension funding n.e.c.'),
  'Travelers Slovenia'                = c('K65.120', 'Non-life insurance'),
  'Wallbox Slovenia'                  = c('C27.120', 'Manufacture of electricity distribution and control apparatus'),
  'Wise Slovenia'                     = c('K64.990', 'Other financial service activities, except insurance and pension funding n.e.c.'),
  'Wüstenrot Slovenia'                = c('K64.190', 'Other monetary intermediation'),
  'Zemanta'                           = c('J62.010', 'Computer programming activities')
)

# 3. Apply the dictionary loop to fill missing rows
for (i in 1:nrow(df)) {
  c_name <- df$company_name[i]
  if ((is.na(df$nace_code[i]) || df$nace_code[i] == "" || df$nace_code[i] == "nan") && c_name %in% names(nace_map)) {
    df$nace_code[i]     <- nace_map[[c_name]][1]
    df$nace_desc_english[i] <- nace_map[[c_name]][2]
  }
}

# ==========================================
# 2. COMPUTE INDUSTRY IMPACT & BASELINE
# ==========================================
df2 <- df %>%
  mutate(
    # Identify industry impact level
    industry_impact = case_when(
      grepl("^H51", nace_code) | grepl("ADRIA|AIRWAYS", company_name, ignore.case = TRUE) ~ "High-Impact",
      grepl("^K64|^K65|^Q86", nace_code) ~ "Medium-Impact",
      TRUE ~ "Low-Impact"
    ),
    
    # Apply baseline adjustment penalty for high-impact sectors
    baseline_adjustment = if_else(industry_impact == "High-Impact", -0.05, 0.00),
    
    # Define default priority tier
    default_esg_priority = case_when(
      grepl("Bank|AXA|AIG|Allianz|Addiko", company_name, ignore.case = TRUE) ~ "G",
      industry_impact == "High-Impact" ~ "E",
      TRUE ~ "G"
    )
  )

# ==========================================
# 3. ESTIMATE HEURISTIC SCORES (WITH SEED)
# ==========================================
set.seed(42)

large_multinational_keywords <- c('bank', 'allianz', 'axa', 'aig', 'bdo', 'generali', 'hofer', 'paypal', 'stripe', 'telekom', 't-mobile', 'revolut', 'smurfit', 'travelers', 'outfit7')

# Helper function to generate heuristic scores per row
estimate_score <- function(name, baseline) {
  name_lower <- tolower(name)
  is_large <- any(sapply(large_multinational_keywords, function(kw) grepl(kw, name_lower)))
  
  # Base score using uniform distribution matching Python's random.uniform
  if (is_large) {
    raw_score <- round(runif(1, 0.65, 0.80), 2)
  } else {
    raw_score <- round(runif(1, 0.35, 0.55), 2)
  }
  
  # Apply baseline adjustment
  final_score <- raw_score + as.numeric(baseline)
  
  # Ensure bounds (0.0 to 1.0)
  final_score <- max(0.0, min(1.0, final_score))
  
  # Classification mapping
  classification <- case_when(
    final_score >= 0.85 ~ "Sustainability Leader",
    final_score >= 0.70 ~ "Advanced",
    final_score >= 0.55 ~ "Progressing",
    final_score >= 0.40 ~ "Emerging",
    final_score >= 0.25 ~ "Limited",
    TRUE ~ "Insufficient"
  )
  
  return(c(raw_score, final_score, classification))
}

# Apply across dataframe rows
scored_matrix <- t(mapply(estimate_score, df2$company_name, df2$baseline_adjustment))

df2$estimated_raw_score   <- as.numeric(scored_matrix[, 1])
df2$estimated_final_score <- as.numeric(scored_matrix[, 2])
df2$estimated_classification <- scored_matrix[, 3]

# ==========================================
# 4. EXPORT FINAL SCORED DATASET
# ==========================================
write_csv(df, 'CompiledCountries_SL_FINAL_GUESSED_SCORES.csv') # or any name you desire!
print("Finished guessing scores and saved to CompiledCountries_SL_FINAL_GUESSED_SCORES.csv!")
