# install.packages(c("httr", "jsonlite", "data.table", "stringdist"))
library(httr)
library(jsonlite)
library(data.table)
library(stringdist)

# ==========================================
# 1. LOAD DATA & ADVANCED PREPARATION
# ==========================================
master_file <- "CompiledCountries - SK.csv"
my_data <- fread(master_file)
api_url <- "https://api.statistics.sk/rpo/v1/search"

# Extract domain root from website column (e.g., "https://www.alfabio.sk/" -> "alfabio")
extract_domain_root <- function(url) {
  if (is.na(url) || trimws(url) == "") return(NA_character_)
  clean_url <- gsub("https?://(www\\.)?", "", url, ignore.case = TRUE)
  clean_url <- strsplit(clean_url, "/|\\?")[[1]][1]
  domain_part <- strsplit(clean_url, "\\.")[[1]][1]
  if (is.null(domain_part) || nchar(domain_part) < 3) return(NA_character_)
  return(domain_part)
}

clean_company_name <- function(name) {
  cleaned <- gsub("\\s*\\([^)]*\\)", "", name)
  cleaned <- gsub("&", " ", cleaned)
  cleaned <- gsub("(?i)\\b(Slovakia|Slovensko|Slovak Republic|SK|s\\.r\\.o\\.|a\\.s\\.|spol\\. s r\\.o\\.)\\b", "", cleaned, perl = TRUE)
  cleaned <- gsub("[^[:alnum:] ]", " ", cleaned)
  cleaned <- trimws(gsub("\\s+", " ", cleaned))
  return(cleaned)
}

strip_diacritics <- function(name) {
  iconv(name, to = "ASCII//TRANSLIT")
}

# Helper to safely extract nested values or return NA
safe_val <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) return(NA_character_)
  return(as.character(x[1]))
}

# ==========================================
# 2. V6 DEEP ENTITY UNPACKER (FULL SPECTRUM)
# ==========================================
unpack_v6_entity <- function(results_df, target_query) {
  top_rec <- results_df[1, ]
  
  # 2.1. Internal RPO ID & Establishment Date
  rpo_id <- safe_val(top_rec$id)
  establishment_date <- safe_val(top_rec$establishment)
  termination_date   <- safe_val(top_rec$termination)
  
  # 2.2. Extract Registration Number (IČO)
  ico_val <- NA_character_
  if ("identifiers" %in% names(top_rec) && is.list(top_rec$identifiers)) {
    id_df <- top_rec$identifiers[[1]]
    if (is.data.frame(id_df) && "value" %in% names(id_df)) ico_val <- safe_val(id_df$value)
  }
  
  # 2.3. Extract Tax & VAT ID (IČ DPH)
  tax_id_val <- NA_character_
  vat_val    <- NA_character_
  if ("taxIdentifiers" %in% names(top_rec) && is.list(top_rec$taxIdentifiers)) {
    tax_df <- top_rec$taxIdentifiers[[1]]
    if (is.data.frame(tax_df) && "value" %in% names(tax_df)) {
      tax_id_val <- safe_val(tax_df$value)
    }
  }
  if (!is.na(ico_val)) vat_val <- paste0("SK", ico_val)
  
  # 2.4. Extract Legal Form (e.g., s.r.o., a.s.)
  legal_form <- NA_character_
  if ("legalForm" %in% names(top_rec) && is.list(top_rec$legalForm)) {
    lf_df <- top_rec$legalForm[[1]]
    if (is.data.frame(lf_df)) {
      if ("value" %in% names(lf_df)) legal_form <- safe_val(lf_df$value)
      else if ("code" %in% names(lf_df)) legal_form <- safe_val(lf_df$code)
    }
  }
  
  # 2.5. Extract Registered Office / Full Address
  full_address <- NA_character_
  municipality <- NA_character_
  postal_code  <- NA_character_
  street       <- NA_character_
  
  if ("addresses" %in% names(top_rec) && is.list(top_rec$addresses)) {
    addr_df <- top_rec$addresses[[1]]
    if (is.data.frame(addr_df) && nrow(addr_df) > 0) {
      latest_addr <- addr_df[nrow(addr_df), ] # Active address
      street      <- safe_val(latest_addr$street)
      b_num       <- safe_val(latest_addr$buildingNumber)
      
      if ("municipality" %in% names(latest_addr)) {
        m_val <- latest_addr$municipality
        municipality <- if (is.data.frame(m_val)) safe_val(m_val$value) else safe_val(m_val)
      }
      
      if ("postalCodes" %in% names(latest_addr) && is.list(latest_addr$postalCodes)) {
        postal_code <- safe_val(latest_addr$postalCodes[[1]])
      }
      
      full_address <- paste(na.omit(c(street, b_num, postal_code, municipality)), collapse = ", ")
    }
  }
  
  # 2.6. Extract Legal Names, Current/Historical & Similarity Score
  current_name <- NA_character_
  matched_name <- NA_character_
  all_names_concat <- NA_character_
  max_sim <- 0.000
  name_type <- "Current Name"
  
  if ("fullNames" %in% names(top_rec) && is.list(top_rec$fullNames)) {
    fn_df <- top_rec$fullNames[[1]]
    if (is.data.frame(fn_df) && "value" %in% names(fn_df)) {
      all_names <- fn_df$value
      current_name <- all_names[length(all_names)]
      all_names_concat <- paste(all_names, collapse = " | ")
      
      for (n_idx in seq_along(all_names)) {
        hist_name <- all_names[n_idx]
        score <- round(1 - stringdist(tolower(target_query), tolower(hist_name), method = "jw"), 3)
        if (score > max_sim) {
          max_sim <- score
          matched_name <- hist_name
          name_type <- if (n_idx < length(all_names)) "Historical Name (Rebranded)" else "Current Name"
        }
      }
    }
  }
  
  # 2.7. Extract SK NACE Industry Classifications
  nace_code <- NA_character_
  if ("economicActivities" %in% names(top_rec) && is.list(top_rec$economicActivities)) {
    nace_df <- top_rec$economicActivities[[1]]
    if (is.data.frame(nace_df)) {
      if ("code" %in% names(nace_df)) {
        nace_code <- paste(unique(na.omit(nace_df$code)), collapse = "; ")
      } else if ("value" %in% names(nace_df)) {
        nace_code <- paste(unique(na.omit(nace_df$value)), collapse = "; ")
      }
    }
  }
  
  # 2.8. Extract Statutory Officers / Directors
  executives <- NA_character_
  if ("statutoryBodies" %in% names(top_rec) && is.list(top_rec$statutoryBodies)) {
    sb_df <- top_rec$statutoryBodies[[1]]
    if (is.data.frame(sb_df) && "formattedName" %in% names(sb_df)) {
      executives <- paste(unique(na.omit(sb_df$formattedName)), collapse = "; ")
    } else if (is.data.frame(sb_df) && "fullName" %in% names(sb_df)) {
      executives <- paste(unique(na.omit(sb_df$fullName)), collapse = "; ")
    }
  }
  
  # 2.9. Extract Partners / Shareholders
  shareholders <- NA_character_
  if ("stakeholders" %in% names(top_rec) && is.list(top_rec$stakeholders)) {
    st_df <- top_rec$stakeholders[[1]]
    if (is.data.frame(st_df) && "formattedName" %in% names(st_df)) {
      shareholders <- paste(unique(na.omit(st_df$formattedName)), collapse = "; ")
    } else if (is.data.frame(st_df) && "fullName" %in% names(st_df)) {
      shareholders <- paste(unique(na.omit(st_df$fullName)), collapse = "; ")
    }
  }
  
  return(list(
    rpo_id = rpo_id,
    ico = ico_val, 
    tax_id = tax_id_val,
    vat = vat_val,
    legal_form = legal_form,
    establishment_date = establishment_date,
    termination_date = termination_date,
    current_official_name = current_name,
    matched_alias = matched_name,
    all_historical_names = all_names_concat,
    full_address = full_address,
    municipality = municipality,
    postal_code = postal_code,
    nace = nace_code,
    executives = executives,
    shareholders = shareholders,
    similarity_score = max_sim,
    name_match_type = name_type
  ))
}

results_list <- vector("list", nrow(my_data))

cat("Launching V6 Enterprise Extractor Engine across", nrow(my_data), "targets...\n\n")

# ==========================================
# 3. RUN MULTI-PASS ENRICHMENT ENGINE
# ==========================================
for (i in 1:nrow(my_data)) {
  target  <- my_data$company_name[i]
  web_url <- my_data$website[i]
  
  if (is.na(target) || trimws(target) == "") next
  
  c_clean  <- clean_company_name(target)
  c_ascii  <- strip_diacritics(c_clean)
  c_anchor <- strsplit(c_clean, " ")[[1]][1]
  c_domain <- extract_domain_root(web_url)
  
  strategies <- list(
    list(query = target,   type = "Pass 1: Exact Match"),
    list(query = c_clean,  type = "Pass 2: Cleaned Match"),
    list(query = c_ascii,  type = "Pass 3: Transliterated Match"),
    list(query = c_anchor, type = "Pass 4: Brand Anchor Match"),
    list(query = c_domain, type = "Pass 5: Domain Keyword Match")
  )
  
  matched <- FALSE
  extracted <- list()
  winning_strategy <- "Not Found / Unregistered"
  
  for (strat in strategies) {
    q_str <- strat$query
    if (is.na(q_str) || trimws(q_str) == "" || nchar(q_str) < 3) next
    
    res <- GET(api_url, query = list(fullName = q_str), add_headers(`User-Agent` = "R-API-Pipeline/6.0"))
    
    if (status_code(res) == 200) {
      parsed <- fromJSON(content(res, as = "text", encoding = "UTF-8"), flatten = FALSE)
      if (!is.null(parsed$results) && is.data.frame(parsed$results) && nrow(parsed$results) > 0) {
        extracted <- unpack_v6_entity(parsed$results, target)
        if (!is.na(extracted$ico)) {
          matched <- TRUE
          winning_strategy <- strat$type
          break
        }
      }
    }
  }
  
  if (matched) {
    results_list[[i]] <- data.table(
      original_target_name = target,
      website = web_url,
      matched_official_name = extracted$current_official_name,
      matched_historical_alias = extracted$matched_alias,
      all_historical_names = extracted$all_historical_names,
      company_id = extracted$ico,
      vat_id = extracted$vat,
      tax_id = extracted$tax_id,
      legal_form = extracted$legal_form,
      establishment_date = extracted$establishment_date,
      full_address = extracted$full_address,
      municipality = extracted$municipality,
      postal_code = extracted$postal_code,
      nace_codes = extracted$nace,
      executives = extracted$executives,
      shareholders = extracted$shareholders,
      similarity_score = extracted$similarity_score,
      name_match_type = extracted$name_match_type,
      search_pass = winning_strategy
    )
    
    cat(sprintf("[%d/%d] MATCH (%s | Score: %.2f):\n      Target: %s -> Legal Name: %s\n      IČO: %s | VAT: %s | City: %s | Address: %s\n", 
                i, nrow(my_data), winning_strategy, extracted$similarity_score,
                target, extracted$current_official_name, extracted$ico, extracted$vat, extracted$municipality, extracted$full_address))
  } else {
    results_list[[i]] <- data.table(
      original_target_name = target,
      website = web_url,
      matched_official_name = NA_character_,
      matched_historical_alias = NA_character_,
      all_historical_names = NA_character_,
      company_id = NA_character_,
      vat_id = NA_character_,
      tax_id = NA_character_,
      legal_form = NA_character_,
      establishment_date = NA_character_,
      full_address = NA_character_,
      municipality = NA_character_,
      postal_code = NA_character_,
      nace_codes = NA_character_,
      executives = NA_character_,
      shareholders = NA_character_,
      similarity_score = 0.000,
      name_match_type = NA_character_,
      search_pass = "Not Found / Unregistered"
    )
    cat(sprintf("[%d/%d] NO MATCH: %s\n", i, nrow(my_data), target))
  }
}

# ==========================================
# 4. EXPORT COMPREHENSIVE DATASETS
# ==========================================
final_results <- rbindlist(results_list, fill = TRUE)

# Save the full audit dump (contains address, executives, legal forms, etc.)
fwrite(final_results, "slovak_company_deep_profiles_v6.csv")

# Merge essential fields back into target CSV schema
my_data[final_results, company_id := i.company_id, on = .(company_name = original_target_name)]
my_data[final_results, vat__id     := i.vat_id,     on = .(company_name = original_target_name)]
my_data[final_results, nace_codes := i.nace_codes, on = .(company_name = original_target_name)]
my_data[final_results, score      := i.similarity_score, on = .(company_name = original_target_name)]

fwrite(my_data, "CompiledCountries_SK_Enriched_V6.csv")

cat("\n========================================================\n")
cat("V6 FULL SPECTRUM PIPELINE COMPLETE!\n")
cat(" -> Master CSV updated: CompiledCountries_SK_Enriched_V6.csv\n")
cat(" -> Deep profile audit: slovak_company_deep_profiles_v6.csv\n")
cat("========================================================\n")
print(table(final_results$search_pass))
