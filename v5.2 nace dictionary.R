library(data.table)

# ==========================================
# 1. DOWNLOAD OFFICIAL NACE REV 2 (ENGLISH)
# ==========================================
cat("Downloading English NACE Rev. 2 dataset from permanent Gist URL...\n")

# Guaranteed stable raw CSV link
nace_url <- "https://gist.githubusercontent.com/b-rodrigues/4218d6daa8275acce80ebef6377953fe/raw/99bb5bc547670f38569c2990d2acada65bb744b3/nace_rev2.csv"

raw_nace <- fread(nace_url)

# Keep only Level 4 codes (Classes like "64.19")
nace_classes <- raw_nace[Level == 4]

# ==========================================
# 2. HELPER TO GET SECTION LETTER
# ==========================================
get_nace_letter_only <- function(div_str) {
  div <- as.integer(div_str)
  if (is.na(div)) return("")
  
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

# ==========================================
# 3. FORMAT TO TARGET STRUCTURE (e.g. K64.190)
# ==========================================
cat("Formatting codes to match SK-NACE 5-digit structure...\n")

nace_classes[, formatted_code := {
  sapply(Code, function(c) {
    # 'c' looks like "64.19". We want "K64.190"
    div_part <- substr(c, 1, 2)
    sec_letter <- get_nace_letter_only(div_part)
    
    # Construct: Letter + 64.19 + 0 
    paste0(sec_letter, c, "0")
  })
}]

# ==========================================
# 4. CLEAN AND SAVE DICTIONARY
# ==========================================
# Keep only formatted code and lowercase english description
nace_dict <- nace_classes[, .(formatted_code, nace_desc_eng = tolower(Description))]

# Write to CSV
fwrite(nace_dict, "nace_english_dict.csv")

cat("SUCCESS! 'nace_english_dict.csv' has been generated in your working directory.\n")