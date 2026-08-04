library(httr)
library(jsonlite)
library(data.table)

# ==========================================
# 1. LOAD AUDIT RESULTS & MASTER DATA
# ==========================================
deep_v6   <- fread("slovak_company_deep_profiles_v6.csv")
master_df <- fread("CompiledCountries - SK.csv")

# Ensure nace_codes column exists as character
deep_v6[, nace_codes := as.character(nace_codes)]

cat("Running Raw Numbers RUZ NACE Extractor (Handling 'Neuvedené' & Flat Strings)...\n\n")

# ==========================================
# 2. ENRICH NACE DESCRIPTIONS (RAW EXTRACTION)
# ==========================================
for (i in 1:nrow(deep_v6)) {
  raw_ico <- deep_v6$company_id[i]
  target  <- deep_v6$original_target_name[i]
  
  # Clean out non-digits (converts "Neuvedené" -> "")
  clean_digits <- ifelse(is.na(raw_ico), "", gsub("[^0-9]", "", as.character(raw_ico)))
  
  # Strict validation check: skip if not numeric
  if (nchar(clean_digits) == 0) {
    cat(sprintf("[%d/%d] SKIPPED (No valid IČO): %s\n", i, nrow(deep_v6), target))
    next
  }
  
  clean_ico <- sprintf("%08d", as.numeric(clean_digits))
  
  search_url <- URLencode(paste0(
    "https://www.registeruz.sk/cruz-public/api/uctovne-jednotky?",
    "zmenene-od=2000-01-01&max-zaznamov=1&ico=", clean_ico
  ))
  
  res <- GET(search_url, add_headers(`User-Agent` = "R-RUZ-Pipeline/4.0"))
  raw_nace_str <- NA_character_
  
  if (status_code(res) == 200) {
    parsed <- fromJSON(content(res, as = "text", encoding = "UTF-8"), flatten = FALSE)
    
    if (!is.null(parsed$id) && length(parsed$id) > 0) {
      unit_id <- parsed$id[1]
      detail_url <- URLencode(paste0("https://www.registeruz.sk/cruz-public/api/uctovna-jednotka?id=", unit_id))
      res_unit <- GET(detail_url, add_headers(`User-Agent` = "R-RUZ-Pipeline/4.0"))
      
      if (status_code(res_unit) == 200) {
        unit_data <- fromJSON(content(res_unit, as = "text", encoding = "UTF-8"), flatten = FALSE)
        
        # EXTRACT RAW NACE (Handles both lists and flat strings/numbers)
        if ("skNace" %in% names(unit_data)) {
          sk_val <- unit_data$skNace
          
          if (is.list(sk_val)) {
            # Sometimes it provides a dictionary
            raw_nace_str <- paste0(sk_val$code, " - ", ifelse(is.null(sk_val$value), "", sk_val$value))
          } else if (is.character(sk_val) || is.numeric(sk_val)) {
            # Usually it just dumps a raw number
            raw_nace_str <- as.character(sk_val)
          }
        }
      }
    }
  }
  
  deep_v6$nace_codes[i] <- raw_nace_str
  cat(sprintf("[%d/%d] %s (IČO: %s) -> Raw NACE: %s\n", 
              i, nrow(deep_v6), target, clean_ico, ifelse(is.na(raw_nace_str), "Not Listed", raw_nace_str)))
}

# ==========================================
# 3. SAVE FINAL ENRICHED CSVs
# ==========================================
fwrite(deep_v6, "slovak_company_deep_profiles_v6.csv")
