library(data.table)

# ==========================================
# 1. LOAD DATA & DICTIONARY
# ==========================================
master_df <- fread("slovak_company_deep_profiles_v6.csv")
nace_dict <- fread("nace_english_dict.csv") 

# ==========================================
# 2. HELPER TO GET SECTION LETTER
# ==========================================
get_nace_letter_only <- function(num_code) {
  if (is.na(num_code)) return("")
  div <- as.integer(substr(sprintf("%05d", as.numeric(num_code)), 1, 2))
  
  if (div %in% 1:3)   return("A")
  if (div %in% 5:9)   return("B")
  if (div %in% 10:33) return("C")
  if (div == 35)      return("D")
  if (div %in% 36:39) return("E")
  if (div %in% 41:43) return("F")
  if (div %in% 45:47) return("G")
  if (div %in% 49:53) return("H")
  if (div %in% 55:56) return("I")
  if (div %in% 58:63) return("J")
  if (div %in% 64:66) return("K")
  if (div == 68)      return("L")
  if (div %in% 69:75) return("M")
  if (div %in% 77:82) return("N")
  if (div == 84)      return("O")
  if (div == 85)      return("P")
  if (div %in% 86:88) return("Q")
  if (div %in% 90:93) return("R")
  if (div %in% 94:96) return("S")
  return("")
}

cat("Running Non-Destructive Formatting and Translation Layer...\n")

# ==========================================
# 3. FORMAT THE CODES (e.g. 64190 -> K64.190)
# ==========================================
master_df[, formatted_code := sapply(as.character(nace_codes), function(raw_val) {
  if (is.na(raw_val) || trimws(raw_val) == "") return(NA_character_)
  
  clean_num <- gsub("[^0-9]", "", raw_val)
  if (nchar(clean_num) == 0) return(NA_character_)
  
  clean_num <- sprintf("%05d", as.numeric(clean_num))
  sec_letter <- get_nace_letter_only(clean_num)
  div_part   <- substr(clean_num, 1, 2)
  group_part <- substr(clean_num, 3, 4)
  class_part <- substr(clean_num, 5, 5)
  
  return(paste0(sec_letter, div_part, ".", group_part, class_part))
})]

# ==========================================
# 4. VLOOKUP-STYLE TRANSLATION (SAFE)
# ==========================================
# This looks up the English text based on the formatted_code without touching row order
master_df[nace_dict, nace_desc_eng := i.nace_desc_eng, on = .(formatted_code)]

# Rename to nace_code and kill the old messy columns
setnames(master_df, old = "formatted_code", new = "nace_code")
master_df[, nace_codes := NULL] 

# ==========================================
# 5. EXPORT FIX
# ==========================================
fwrite(master_df, "CompiledCountries_SK_Translated.csv")

cat("SUCCESS! Output safely saved to: CompiledCountries_SK_Translated.csv\n")
