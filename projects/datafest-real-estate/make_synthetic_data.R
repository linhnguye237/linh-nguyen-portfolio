# make_synthetic_data.R
# Generates FAKE data with the same column names the original analysis used.
# The real Savills files were deleted for confidentiality, so every number here
# is invented. Results from analysis.R on this data will NOT match the slides.
#
# Run from the project folder:  Rscript make_synthetic_data.R

library(tidyverse)

set.seed(2025)
dir.create("data", showWarnings = FALSE)

# ---- City / market setup ----------------------------------------------------
# rent_A   = typical Class A rent ($/SF) in that market
# occ_base = long-run office occupancy the market recovers to after 2020
# p_fin / p_tech = share of leases signed by finance / tech tenants
cities <- tribble(
  ~market,           ~city,           ~state, ~region,     ~n_leases, ~rent_A, ~occ_base, ~p_fin, ~p_tech,
  "Manhattan",       "New York",      "NY",   "Northeast", 14000,     80,      0.45,      0.30,   0.18,
  "San Francisco",   "San Francisco", "CA",   "West",       3000,     74,      0.38,      0.20,   0.26,
  "Houston",         "Houston",       "TX",   "South",     12000,     33,      0.58,      0.09,   0.13,
  "Houston",         "The Woodlands", "TX",   "South",       900,     33,      0.58,      0.08,   0.13,
  "Austin",          "Austin",        "TX",   "South",      5000,     41,      0.60,      0.09,   0.20,
  "Los Angeles",     "Los Angeles",   "CA",   "West",       5500,     43,      0.42,      0.11,   0.17,
  "Los Angeles",     "El Segundo",    "CA",   "West",        450,     43,      0.42,      0.08,   0.22,
  "Los Angeles",     "Culver City",   "CA",   "West",        350,     43,      0.42,      0.06,   0.28,
  "Philadelphia",    "Philadelphia",  "PA",   "Northeast",  1500,     37,      0.38,      0.16,   0.11,
  # Markets below have leases but no row in the occupancy file, so they drop
  # out at the join. This is a guess at why the original analysis ended up
  # with only seven cities.
  "Chicago",         "Chicago",       "IL",   "Midwest",    5000,     42,      NA,        0.18,   0.14,
  "Dallas/Ft Worth", "Dallas",        "TX",   "South",      5000,     31,      NA,        0.14,   0.14,
  "Washington D.C.", "Washington",    "DC",   "Northeast",  4000,     56,      NA,        0.10,   0.12,
  "Atlanta",         "Atlanta",       "GA",   "South",      3500,     32,      NA,        0.13,   0.15,
  "Boston",          "Boston",        "MA",   "Northeast",  3000,     62,      NA,        0.20,   0.20
)

quarters <- paste0("Q", 1:4)
time_grid <- expand_grid(year = 2018:2024, quarter = quarters) %>%
  mutate(t = row_number() - 1)

# ---- Market-level rent and availability (one value per market/quarter/class) --
market_base <- cities %>% distinct(market, rent_A, occ_base)

market_rent <- market_base %>%
  cross_join(time_grid) %>%
  cross_join(tibble(internal_class = c("A", "O"))) %>%
  mutate(
    internal_class_rent = rent_A * if_else(internal_class == "O", 0.88, 1) *
      (1 + 0.01 * (year - 2018)) + rnorm(n(), 0, 1),
    internal_class_rent = round(internal_class_rent, 2)
  ) %>%
  select(market, year, quarter, internal_class, internal_class_rent)

market_avail <- market_base %>%
  cross_join(time_grid) %>%
  mutate(
    overall_rent = round(rent_A * 0.85 * (1 + 0.01 * (year - 2018)) + rnorm(n(), 0, 1), 2),
    availability_proportion = pmin(pmax(0.14 + 0.005 * t + rnorm(n(), 0, 0.01), 0.05), 0.45),
    sublet_availability_proportion = availability_proportion * runif(n(), 0.10, 0.25),
    available_space = round(runif(n(), 2e7, 9e7))
  ) %>%
  select(market, year, quarter, overall_rent, availability_proportion,
         sublet_availability_proportion, available_space)

# ---- Occupancy file: 2020-2024, only the six markets with data --------------
# Q1 2020 is pre-COVID (high), then a crash and a slow recovery toward occ_base.
# Q2 and Q3 sit slightly lower than Q1 and Q4.
occupancy <- market_base %>%
  filter(!is.na(occ_base)) %>%
  cross_join(time_grid %>% filter(year >= 2020) %>% mutate(t = row_number() - 1)) %>%
  mutate(
    level = if_else(t == 0, occ_base * 1.25, occ_base * (0.35 + 0.65 * (1 - exp(-(t - 1) / 5)))),
    seasonal = if_else(quarter %in% c("Q2", "Q3") & t > 0, -0.03, 0),
    avg_occupancy_proportion = pmin(pmax(level + seasonal + rnorm(n(), 0, 0.015), 0.05), 1),
    starting_occupancy_proportion = pmin(pmax(avg_occupancy_proportion + rnorm(n(), 0, 0.02), 0.05), 1),
    ending_occupancy_proportion = pmin(pmax(avg_occupancy_proportion + rnorm(n(), 0, 0.02), 0.05), 1)
  ) %>%
  select(year, quarter, market, starting_occupancy_proportion,
         ending_occupancy_proportion, avg_occupancy_proportion)

# ---- Lease-level file -------------------------------------------------------
other_industries <- c("Legal Services", "Healthcare", "Energy & Utilities",
                      "Business, Professional, and Consulting Services",
                      "Real Estate", "Government", "Retail", "Nonprofit")

leases <- cities %>%
  uncount(n_leases) %>%
  mutate(
    year = sample(2018:2024, n(), replace = TRUE),
    quarter = sample(quarters, n(), replace = TRUE),
    monthsigned = (as.integer(substr(quarter, 2, 2)) - 1) * 3 + sample(1:3, n(), replace = TRUE),
    internal_class = sample(c("A", "O"), n(), replace = TRUE, prob = c(0.45, 0.55)),
    u = runif(n()),
    internal_industry = case_when(
      u < p_fin ~ "Financial Services and Insurance",
      u < p_fin + p_tech ~ "Technology, Advertising, Media, and Information",
      TRUE ~ sample(other_industries, n(), replace = TRUE)
    ),
    transaction_type = sample(c("New", "Renewal", "Relocation", "Expansion", "Sublease"),
                              n(), replace = TRUE, prob = c(0.38, 0.27, 0.15, 0.10, 0.10)),
    # Mostly small leases, plus a few large deals and a handful of mega leases
    size_type = sample(c("standard", "large", "mega"), n(), replace = TRUE,
                       prob = c(0.983, 0.015, 0.002)),
    leasedSF = round(case_when(
      size_type == "standard" ~ rlnorm(n(), meanlog = 8.3, sdlog = 0.9),
      size_type == "large" ~ runif(n(), 60000, 250000),
      TRUE ~ runif(n(), 300000, 800000)
    )),
    company_name = paste("Company", sprintf("%05d", sample(1:20000, n(), replace = TRUE))),
    internal_submarket = paste(city, sample(c("CBD", "Midtown", "North", "South", "West"),
                                            n(), replace = TRUE)),
    CBD_suburban = if_else(str_detect(internal_submarket, "CBD|Midtown"), "CBD", "Suburban")
  ) %>%
  left_join(market_rent, by = c("market", "year", "quarter", "internal_class")) %>%
  left_join(market_avail, by = c("market", "year", "quarter")) %>%
  select(year, quarter, monthsigned, market, city, state, region, internal_submarket,
         CBD_suburban, internal_class, leasedSF, company_name, internal_industry,
         transaction_type, internal_class_rent, overall_rent, availability_proportion,
         sublet_availability_proportion, available_space) %>%
  arrange(year, quarter, market)

# ---- City economic file -----------------------------------------------------
# The original labour force / employment / unemployment series were pulled by
# hand for the seven cities; this layout is assumed, not copied.
econ_base <- tribble(
  ~city_state,         ~lf_2018, ~lf_growth, ~rate_base, ~rate_2020,
  "New York, NY",      9900000,  -0.002,     0.062,      0.165,
  "San Francisco, CA", 2550000,  -0.001,     0.028,      0.082,
  "Houston, TX",       3350000,   0.018,     0.043,      0.088,
  "The Woodlands, TX",  320000,   0.030,     0.040,      0.085,
  "Austin, TX",        1190000,   0.040,     0.030,      0.070,
  "Los Angeles, CA",   5100000,   0.001,     0.047,      0.123,
  "Philadelphia, PA",  3120000,   0.008,     0.042,      0.089
)

econ <- econ_base %>%
  cross_join(tibble(year = 2018:2024)) %>%
  mutate(
    avg_labour_force = round(lf_2018 * (1 + lf_growth)^(year - 2018) *
                               if_else(year == 2020, 0.985, 1)),
    unemployment_rate = case_when(
      year == 2020 ~ rate_2020,
      year == 2021 ~ (rate_base + rate_2020) / 2,
      TRUE ~ rate_base + rnorm(n(), 0, 0.003)
    ),
    unemployment = round(avg_labour_force * unemployment_rate),
    employment = avg_labour_force - unemployment
  ) %>%
  select(city_state, year, avg_labour_force, employment, unemployment)

# ---- Write files ------------------------------------------------------------
write.csv(leases, "data/Leases.csv", row.names = FALSE)
write.csv(occupancy, "data/Major Market Occupancy Data-revised.csv", row.names = FALSE)
write.csv(econ, "data/City Economic Data.csv", row.names = FALSE)

cat("Wrote", nrow(leases), "leases,", nrow(occupancy), "occupancy rows,",
    nrow(econ), "economic rows to data/\n")
