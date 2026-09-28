# Call the API
usethis::edit_r_environ()


# ============================================================
# IPUMS CPS Extract
# Project:
# Occupational Structure and Wage Changes in the U.S. Labor Market
#
# Samples:
# March Basic Monthly CPS, 1982-2024
# ============================================================

# ------------------------------------------------------------
# 1. Packages
# ------------------------------------------------------------

packages <- c(
  "ipumsr",
  "tidyverse"
)

new_packages <- packages[
  !(packages %in% installed.packages()[, "Package"])
]

if (length(new_packages) > 0) {
  install.packages(new_packages)
}

library(ipumsr)
library(tidyverse)


# ------------------------------------------------------------
# 2. Check IPUMS API key
# ------------------------------------------------------------

api_key <- Sys.getenv("IPUMS_API_KEY")

if (api_key == "") {
  stop(
    paste0(
      "IPUMS_API_KEY is not available.\n",
      "Please store your IPUMS API key in .Renviron."
    )
  )
}

message("IPUMS API key detected.")

# ------------------------------------------------------------
# 3. Set and activate the API key
# ------------------------------------------------------------
set_ipums_api_key(api_key)

# ------------------------------------------------------------
# 4. Query and set samples and variables
# ------------------------------------------------------------
# Set the core variables required for the analysis:
# - YEAR: Year
# - AGE: Age
# - EMPSTAT: Employment status
# - INCWAGE: Wage income
# - OCC1990: 1990 consistent occupational code
# - ASECWT: Survey weight
vars_to_include <- c("YEAR", "AGE", "EMPSTAT", "INCWAGE", "OCC1990", "ASECWT")

# ------------------------------------------------------------
# 5. Define the Extract request
# ------------------------------------------------------------

# 1. Dynamically generate all 41 March ASEC sample IDs from 1983 to 2023
sample_ids <- sprintf("cps%d_03s", 1983:2023)

# View the generated sample list (confirm that it contains all 41 years)
length(sample_ids) # Should output 41
print(head(sample_ids))

# 2. Set the variables to extract
vars_to_include <- c("YEAR", "AGE", "EMPSTAT", "INCWAGE", "OCC1990", "ASECWT")

# 3. Define the full Extract request
cps_extract_def <- define_extract_micro(
  collection = "cps",
  description = "40 Years Full Time-Series Occupational Analysis (1983-2023)",
  samples = sample_ids,
  variables = vars_to_include
)

# 4. Submit the request and wait for the download
set_ipums_api_key(Sys.getenv("IPUMS_API_KEY"))

submitted_extract <- submit_extract(cps_extract_def)
downloadable_extract <- wait_for_extract(submitted_extract)
downloaded_files <- download_extract(downloadable_extract, download_dir = ".", overwrite = TRUE)

# 5. Read the full microdata
cps_raw <- read_ipums_micro(downloaded_files)

# ============================================================
# 6. Install and load additional analysis packages (if not already installed)
# ============================================================
analysis_packages <- c("srvyr", "scales", "ggthemes")
new_analysis_packages <- analysis_packages[!(analysis_packages %in% installed.packages()[, "Package"])]
if (length(new_analysis_packages) > 0) {
  install.packages(new_analysis_packages)
}

library(srvyr)      # Complex survey weights (required)
library(scales)     # Format numbers, percentages, and currency in charts
library(ggthemes)   # Provides professional academic-style plot themes

# ============================================================
# 7. Build the annual 1983–2023 CPI-U adjustment table (in 2023 dollars)
# Data source: U.S. Bureau of Labor Statistics (BLS) Consumer Price Index
# ============================================================
cpi_table <- tibble(
  YEAR = 1983:2023,
  cpi = c(
    99.6, 103.9, 107.6, 109.6, 113.6, 118.3, 124.0, 130.7, 136.2, 140.3, # 1983-1992
    144.5, 148.2, 152.4, 156.9, 160.5, 163.0, 166.6, 172.2, 177.1, 179.9, # 1993-2002
    184.0, 188.9, 195.3, 201.6, 207.342, 215.303, 214.537, 218.056,       # 2003-2010
    224.939, 229.594, 232.957, 236.736, 237.017, 240.007, 245.120,       # 2011-2017
    251.107, 255.657, 258.811, 270.970, 292.655, 304.702                 # 2018-2023
  )
) %>%
  mutate(cpi_ratio = 304.702 / cpi) # Use the 2023 CPI (304.702) as the base

# ============================================================
# 8. Data filtering and variable construction (Data Filtering & Transformations)
# ============================================================
message("Cleaning 41 years of microdata and constructing variables...")

cps_cleaned <- cps_raw %>%
  # 1. Keep prime-age (25–64) employed civilians
  filter(AGE >= 25 & AGE <= 64) %>%
  filter(EMPSTAT %in% c(10, 12)) %>% # 10: At work; 12: Has job, not at work
  filter(INCWAGE > 0 & INCWAGE < 9999998) %>% # Remove nonresponses, NIU, and top-coded missing values
  filter(OCC1990 > 0 & OCC1990 < 991) %>% # Remove unclassified occupations
  # 2. Match CPI for inflation adjustment and generate real wages in 2023 dollars
  left_join(cpi_table, by = "YEAR") %>%
  mutate(real_incwage = INCWAGE * cpi_ratio) %>%
  # 2. Construct four task categories based on Jaimovich & Siu (2020)
  mutate(
    skill_tier_4 = case_when(
      # 1. Non-routine cognitive (high-skill: managers, professionals, and technicians)
      OCC1990 >= 3 & OCC1990 <= 235 ~ "1. Non-Routine Cognitive (High-Skill)",
      
      # 2. Routine cognitive (middle-skill white-collar: sales, administrative, and clerical workers)
      OCC1990 >= 243 & OCC1990 <= 389 ~ "2. Routine Cognitive (White-Collar)",
      
      # 3. Routine manual (middle-skill blue-collar: machine operators, repair, construction, and transportation/assembly workers)
      OCC1990 >= 503 & OCC1990 <= 889 ~ "3. Routine Manual (Blue-Collar)",
      
      # 4. Non-routine manual (low-skill: food service, household services, personal care, security, and other service jobs)
      OCC1990 >= 403 & OCC1990 <= 469 ~ "4. Non-Routine Manual (Service)",
      
      # Exclude agriculture, forestry, and fishing (473–499), as well as unclassified occupations and military personnel (890+)
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(skill_tier_4))

# ============================================================
# 9. Construct the survey design object (srvyr survey design using ASECWT)
# ============================================================
message("Constructing the survey weight object (ASECWT)...")
cps_svy <- cps_cleaned %>%
  as_survey_design(weights = ASECWT)

# ============================================================
# 10. Calculate time-series measures (weighted calculations)
# ============================================================

# (A) Calculate annual employment shares for the four occupational tiers from 1983 to 2023
emp_share_41yrs <- cps_svy %>%
  group_by(YEAR, skill_tier_4) %>%  # Updated: replaced with skill_tier_4
  summarize(
    weighted_pop = survey_total(),
    .groups = "drop_last"
  ) %>%
  mutate(
    emp_share = weighted_pop / sum(weighted_pop)
  ) %>%
  ungroup()

# (B) Calculate annual real median wages for each occupational tier from 1983 to 2023
wage_trend_41yrs <- cps_svy %>%
  group_by(YEAR, skill_tier_4) %>%  # Updated: replaced with skill_tier_4
  summarize(
    median_real_wage = survey_median(real_incwage),
    .groups = "drop"
  ) %>%
  # Calculate the cumulative real wage growth index using 1983 as the base year (Index = 100)
  group_by(skill_tier_4) %>%       # Updated: replaced with skill_tier_4
  mutate(
    base_wage = median_real_wage[YEAR == 1983],
    wage_index = (median_real_wage / base_wage) * 100
  ) %>%
  ungroup()

# (C) Calculate polarization curve data for detailed occupations (OCC1990), comparing 1983 and 2023 (no changes needed; still based on OCC1990)
occ_polarization_41yrs <- cps_svy %>%
  filter(YEAR %in% c(1983, 2023)) %>%
  group_by(YEAR, OCC1990) %>%
  summarize(
    total_pop = survey_total(),
    median_wage = survey_median(real_incwage),
    .groups = "drop"
  ) %>%
  group_by(YEAR) %>%
  mutate(share = total_pop / sum(total_pop)) %>%
  ungroup() %>%
  select(OCC1990, YEAR, share, median_wage) %>%
  pivot_wider(names_from = YEAR, values_from = c(share, median_wage), names_prefix = "yr_") %>%
  filter(!is.na(share_yr_1983) & !is.na(share_yr_2023)) %>%
  mutate(
    share_change_pp = (share_yr_2023 - share_yr_1983) * 100, # Percentage-point change
    percentile_1983 = percent_rank(median_wage_yr_1983) * 100 # 1983 skill percentile
  )

library(dplyr)
library(scales)

emp_share_5yrs <- emp_share_41yrs |>
  filter(
    YEAR %in% seq(1983, 2023, by = 5)
  ) |>
  select(
    YEAR,
    skill_tier_4,
    emp_share
  ) |>
  arrange(
    YEAR,
    skill_tier_4
  )

emp_share_5yrs



# ============================================================
# 11. Generate and display the core visualizations (Three Substantive Visualizations)
# ============================================================

# Define a consistent publication-style plotting theme
custom_theme <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, margin = margin(b = 6)),
    plot.subtitle = element_text(color = "gray30", size = 10, margin = margin(b = 12)),
    plot.caption = element_text(color = "gray50", size = 8, hjust = 0),
    panel.grid.minor = element_blank(),
    legend.position = "top",
    legend.title = element_blank()
  )

# Define a standard academic color palette for the four categories
tier_colors_4 <- c(
  "1. Non-Routine Cognitive (High-Skill)" = "#2b5c8f", # High-skill: dark blue
  "2. Routine Cognitive (White-Collar)"  = "#e6550d", # Routine white-collar: vermilion/warm orange
  "3. Routine Manual (Blue-Collar)"     = "#fdae6b", # Routine blue-collar: light orange
  "4. Non-Routine Manual (Service)"     = "#7570b3"  # Low-skill service: purple
)

# ------------------------------------------------------------
# Chart 1: Employment Share descriptive chart
# ------------------------------------------------------------
emp_share_5yrs |>
  mutate(
    emp_share = percent(emp_share, accuracy = 0.1)
  )

emp_share_table <- emp_share_5yrs |>
  pivot_wider(
    names_from = skill_tier_4,
    values_from = emp_share
  ) |>
  mutate(
    across(
      -YEAR,
      ~ percent(.x, accuracy = 0.1)
    )
  )

emp_share_table



# ------------------------------------------------------------
# Chart 1: Job Polarization
# ------------------------------------------------------------


p1 <- ggplot(emp_share_41yrs, aes(x = YEAR, y = emp_share, color = skill_tier_4, group = skill_tier_4)) + 
  geom_point(size = 1) + geom_line(size = 1.3) + 
  scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 0.50)) + scale_x_continuous(breaks = seq(1983, 2023, by = 5)) + 
  scale_color_manual(values = tier_colors_4) + 
  labs( title = "Figure 1: 40-Year continuous Trend of U.S. Job Polarization (1983–2023)", 
        x = "Year", y = "Percentage of Total U.S. Employment", 
        caption = "Data Source: IPUMS CPS March ASEC (1983–2023). Sample: Employed civilians aged 25–64." ) +
  custom_theme

print(p1)




# ------------------------------------------------------------
# Figure 1: Occupational structure of U.S. employment
# ------------------------------------------------------------

p2 <- ggplot(
  emp_share_41yrs,
  aes(
    x = YEAR,
    y = emp_share,
    fill = skill_tier_4
  )
) +
  geom_area(
    position = "stack"
  ) +
  scale_y_continuous(
    labels = percent_format(accuracy = 1),
    limits = c(0, 1),
    expand = c(0, 0)
  ) +
  scale_x_continuous(
    breaks = seq(1983, 2023, by = 5)
  ) +
  scale_fill_manual(
    values = tier_colors_4
  ) +
  labs(
    title = "Figure 2: Changes in the Occupational Structure of U.S. Employment (1983–2023)",
    x = "Year",
    y = "Share of Total Employment",
    fill = "Skill Tier",
    caption = "Data Source: IPUMS CPS March ASEC (1983–2023). Sample: Employed civilians aged 25–64."
  ) +
  custom_theme

print(p2)



# ------------------------------------------------------------
# Chart 2: real median wages chart
# ------------------------------------------------------------

wage_5yrs <- wage_trend_41yrs %>%
  filter(
    YEAR %in% seq(1983, 2023, by = 5)
  ) %>%
  select(
    YEAR,
    skill_tier_4,
    median_real_wage
  ) %>%
  arrange(
    YEAR,
    skill_tier_4
  )

wage_5yrs

wage_5yrs_table <- wage_5yrs %>%
  pivot_wider(
    names_from = skill_tier_4,
    values_from = median_real_wage
  )

wage_5yrs_table



# ------------------------------------------------------------
# Chart 2: 41-year cumulative growth in real median wages (1983 = 100)
# ------------------------------------------------------------

p3 <- ggplot(wage_trend_41yrs, aes(x = YEAR, y = wage_index, color = skill_tier_4, group = skill_tier_4)) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray60") +
  geom_line(size = 1.2) +
  scale_x_continuous(breaks = seq(1983, 2023, by = 5)) +
  scale_y_continuous(labels = function(x) paste0(x, " (", ifelse(x>=100, "+", ""), x-100, "%)")) +
  scale_color_manual(values = tier_colors_4) + 
  
  annotate(
    "rect",
    xmin = 2001,
    xmax = 2002,
    ymin = -Inf,
    ymax = Inf,
    fill = "grey70",
    alpha = 0.12,
    color = NA
  ) +
  
  annotate(
    "rect",
    xmin = 2007.9,
    xmax = 2009.5,
    ymin = -Inf,
    ymax = Inf,
    fill = "grey70",
    alpha = 0.12,
    color = NA
  ) +
  
  annotate(
    "rect",
    xmin = 2020,
    xmax = 2021,
    ymin = -Inf,
    ymax = Inf,
    fill = "grey70",
    alpha = 0.12,
    color = NA
  ) +
  
  geom_hline(
    yintercept = 100,
    linetype = "dashed",
    color = "grey55",
    linewidth = 0.6
  ) +
  labs(
    title = "Figure 3: Cumulative Real Growth in Median Annual Earnings by Task Tier (1983 = 100)",
    subtitle = "Real median annual wage index adjusted for inflation using CPI-U (2023 Dollars)",
    x = "Year",
    y = "Real Wage Index (1983 = 100)",
    caption = "Data Source: IPUMS CPS March ASEC (1983–2023). Adjusted using BLS CPI-U."
  ) +
  custom_theme

print(p3)


# ------------------------------------------------------------
# Chart 3: 
# ------------------------------------------------------------
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

wage_compare <- wage_trend_41yrs %>%
  filter(YEAR %in% c(1983, 2023)) %>%
  select(
    YEAR,
    skill_tier_4,
    median_real_wage
  ) %>%
  pivot_wider(
    names_from = YEAR,
    values_from = median_real_wage,
    names_prefix = "wage_"
  ) %>%
  mutate(
    growth_pct = (wage_2023 / wage_1983 - 1) * 100
  )

p3_dumbbell <- ggplot(
  wage_compare,
  aes(
    y = reorder(skill_tier_4, wage_2023)
  )
) +
  
  # 1983 -> 2023
  geom_segment(
    aes(
      x = wage_1983,
      xend = wage_2023,
      yend = reorder(skill_tier_4, wage_2023)
    ),
    color = "grey70",
    linewidth = 1.5
  ) +
  
  # 1983
  geom_point(
    aes(x = wage_1983),
    size = 3.5,
    color = "grey45"
  ) +
  
  # 2023
  geom_point(
    aes(
      x = wage_2023,
      color = skill_tier_4
    ),
    size = 4
  ) +
  
  # 2023 wage label
  geom_text(
    aes(
      x = wage_2023,
      label = paste0(
        dollar(wage_2023, accuracy = 100),
        "\n(",
        ifelse(growth_pct >= 0, "+", ""),
        round(growth_pct, 1),
        "%)"
      ),
      color = skill_tier_4
    ),
    hjust = -0.1,
    size = 3.4,
    show.legend = FALSE
  ) +
  
  scale_x_continuous(
    labels = dollar_format(
      accuracy = 5000
    ),
    expand = expansion(
      mult = c(0.03, 0.18)
    )
  ) +
  
  scale_color_manual(
    values = tier_colors_4
  ) +
  
  labs(
    title = "Figure 4: Real Median Earnings Increased Across Occupational Groups",
    subtitle = "1983 vs. 2023, expressed in 2023 dollars",
    x = "Real median annual wage",
    y = NULL,
    color = "Occupational Type",
    caption = "Data Source: IPUMS CPS March ASEC (1983–2023). Inflation-adjusted using BLS CPI-U."
  ) +
  
  custom_theme +
  
  theme(
    legend.position = "top",
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank()
  )

print(p3_dumbbell)