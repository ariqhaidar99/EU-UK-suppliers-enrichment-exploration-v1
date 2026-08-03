# install.packages(c("data.table", "stringr", "polygotr"))
library(data.table)
library(stringr)
library(polyglotr)

# README: Before doing anything, please ensure all NACE are manually filled from https://www.stop-neplacniki.si/ 
# README2: please also ensure that there are only 5 variables when running str(df) later
# 1. Load the dataset (forcing all columns to character)
df <- fread("CompiledCountries - SL (fixed2).csv", colClasses = "character") 
# or whatever your fixed file name is

# 2. Convert literal "N/A" text strings to true R missing values (NA)
df[df == "N/A"] <- NA

# 3. Extract clean NACE code WITH LETTER (e.g., "K64.190") and Slovenian description
# Added [A-Z]? to grab the leading sector letter
df$nace_code <- str_extract(df$nace_code_slo, "[A-Z]?\\d+\\.\\d+")
df$nace_desc_slo <- trimws(sub(".*-", "", df$nace_code_slo))

# 4. Translate Slovenian descriptions into English
print("Translating NACE descriptions to English...")

for (i in 1:nrow(df)) {
  if (!is.na(df$nace_desc_slo[i]) && df$nace_desc_slo[i] != "") {
    
    # Translate using polyglotr
    df$nace_desc_eng[i] <- google_translate(
      df$nace_desc_slo[i], 
      target_language = "en", 
      source_language = "sl"
    )
    
    cat(sprintf("[%d/%d] %s -> %s\n", i, nrow(df), df$nace_desc_slo[i], df$nace_desc_english[i]))
    
    # Polite delay between requests to keep Google happy
    Sys.sleep(0.5) 
  }
}

# 5. Reorder columns and export final output
df$nace_code_slo <- NULL # Drop combined raw column
setcolorder(df, c("company_name", "website", "vat_id", "reg_id", "nace_code", "nace_desc_slo", "nace_desc_eng"))

fwrite(df, "CompiledCountries_SL_FINAL_COMPLETE.csv")
print("Slovenia is 100% finished and saved to CompiledCountries_SL_FINAL_COMPLETE.csv!")
