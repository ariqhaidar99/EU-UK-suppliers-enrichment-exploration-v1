# install.packages(c("data.table", "DBI", "RPostgres"))
library(data.table)
library(DBI)
library(RPostgres)

# ==========================================
# 1. CONNECT TO POSTGRESQL
# ==========================================
con <- dbConnect(RPostgres::Postgres(),
                 dbname = "your_dbname_here", # Replace with your dbname
                 host = "localhost",
                 port = 5432,
                 user = "postgres",
                 password = "your_password_here") # Replace with your password

# ==========================================
# 2. CONVERT UTF-16 TO UTF-8 & LOAD CSV
# Please nuke everything except the "Matična številka" and "Popolno ime" columns using excel
# ==========================================
file_con <- file("opsiprs.csv", encoding = "UTF-16LE") 
# default csv name if downloading from https://data.europa.eu/data/datasets/poslovni-register-slovenije?locale=en
lines <- readLines(file_con, warn = FALSE)
close(file_con)

writeLines(lines, "opsiprs_utf8.csv", useBytes = TRUE)

raw_registry <- fread("opsiprs_utf8.csv", sep = ",", quote = "\"", colClasses = "character")

# ==========================================
# 3. NORMALIZE COLUMN NAMES FOR SQL
# ==========================================
# This maps the Slovenian headers to the clean English names your SQL query expects
# (Update the strings in 'old =' if your exact Slovenian column names differ slightly)
setnames(raw_registry, 
         old = c("Matična številka", "Popolno ime"), 
         new = c("reg_id", "company_name"), 
         skip_absent = TRUE)

# ==========================================
# 4. PUSH TABLE TO POSTGRES & INDEX
# ==========================================
dbWriteTable(con, "ajpes_registry", raw_registry, overwrite = TRUE, row.names = FALSE)

# Create extension and GIN trigram index for fast fuzzy matching
dbExecute(con, "CREATE EXTENSION IF NOT EXISTS pg_trgm;")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ajpes_company_name_trgm ON ajpes_registry USING gin (company_name gin_trgm_ops);")

dbDisconnect(con)

print("Success! opsiprs.csv normalized, loaded, and indexed in PostgreSQL.")

# ==========================================
# 5. LOAD & CLEAN TARGET LIST
# ==========================================
# Read the target file
my_data <- fread("CompiledCountries - SL (reset).csv")
my_companies <- data.frame(original_target_name = my_data$company_name)

# DATA CLEANING: Strip the country name out (case-insensitive)
my_companies$clean_search_name <- gsub("(?i)\\bSlovenia\\b|\\bSlovenija\\b", "", my_companies$original_target_name)

# Strip any extra whitespace left behind
my_companies$clean_search_name <- trimws(my_companies$clean_search_name)

# Push the cleaned target companies to a temp table in SQL
dbWriteTable(con, "my_companies_temp", my_companies, overwrite = TRUE, temporary = TRUE)

print("Target companies successfully pushed to temp table!")

# ==========================================
# 6. EXECUTE THE SQL FUZZY MATCH QUERY
# ==========================================
sql_query <- "
SELECT 
    m.original_target_name,
    m.clean_search_name,
    r.company_name AS matched_official_name,
    r.reg_id,
    ROUND((1 - (m.clean_search_name <-> r.company_name))::numeric, 3) AS similarity_score
FROM 
    my_companies_temp m
CROSS JOIN LATERAL (
    SELECT company_name, reg_id
    FROM ajpes_registry
    ORDER BY m.clean_search_name <-> company_name ASC
    LIMIT 1
) r;
"

matched_results <- dbGetQuery(con, sql_query)

# Disconnect when completely finished
dbDisconnect(con)

# Save output
fwrite(matched_results, "v2_slovenia_matched_results.csv")
print("Pipeline complete! Matched results saved.")

# Note: please re-check anything with an similarity score of below 0.600