# Data-Visualization

# Occupational Structure and Wage Changes in the U.S. Labor Market

This project studies how the occupational structure of the U.S. labor market has changed over the past four decades and how real wages have evolved across different types of occupations.

Using IPUMS Current Population Survey (CPS) microdata from 1983 to 2023, the project examines changes in employment shares and real median earnings across four broad occupational task groups.

## Research Questions

The project focuses on three main questions:

1. How has the occupational structure of the U.S. labor market changed from 1983 to 2023?
2. How have real median wages changed across different occupational groups?
3. Do employment and wage patterns show evidence of long-run job polarization?

## Data

The main data source is the **IPUMS Current Population Survey (CPS), March ASEC**.

The analysis uses annual samples from **1983 to 2023**, covering 41 years.

The following variables are used:

* `YEAR` — survey year
* `AGE` — respondent age
* `EMPSTAT` — employment status
* `INCWAGE` — wage and salary income
* `OCC1990` — consistent 1990 occupational classification
* `ASECWT` — CPS survey weight

Because the CPS microdata are large, the original `.dat.gz` and related raw extract files are not included in this GitHub repository.

## Sample

The analysis focuses on:

* Civilians aged **25–64**
* Employed individuals
* Individuals with positive and non-missing wage income
* Individuals with valid occupation codes
* Four broad occupational task groups

The CPS survey weights (`ASECWT`) are used throughout the analysis to produce population-representative estimates.

## Occupational Classification

Occupations are grouped into four broad categories based on task characteristics:

| Occupational Group    | Description                                                                              |
| --------------------- | ---------------------------------------------------------------------------------------- |
| Non-Routine Cognitive | Managers, professionals, and technicians                                                 |
| Routine Cognitive     | Sales, administrative, and clerical occupations                                          |
| Routine Manual        | Machine operators, repair, construction, transportation, and assembly occupations        |
| Non-Routine Manual    | Food service, personal care, household services, security, and other service occupations |

Agriculture, forestry, fishing, military, and unclassified occupations are excluded from the four-group analysis.

## Wage Adjustment

Nominal wage income is converted into **real 2023 dollars** using the annual U.S. Consumer Price Index for All Urban Consumers (CPI-U).

The 2023 CPI is used as the base year:

> Real Wage = Nominal Wage × (CPI in 2023 / CPI in Year t)

This allows wage changes to be compared across years without the effects of inflation.

## Methodology

The project uses survey-weighted calculations through the `srvyr` package.

### Employment Shares

For each year and occupational group, weighted employment is calculated using `ASECWT`.

The employment share of each group is then calculated as:

```text
Employment Share =
Weighted Employment in Group /
Total Weighted Employment
```

### Real Median Wages

For each occupational group and year, the survey-weighted median of inflation-adjusted annual earnings is calculated.

### Wage Growth Index

To compare long-run wage growth, 1983 is used as the base year:

```text
Wage Index =
(Median Real Wage in Year t /
 Median Real Wage in 1983) × 100
```

Therefore, an index value of 100 represents the 1983 wage level.

## Visualizations

The analysis produces four main figures.

### Figure 1 — U.S. Job Polarization

A continuous time-series chart showing changes in the employment share of the four occupational groups from 1983 to 2023.

### Figure 2 — Occupational Structure

A stacked area chart showing how the composition of U.S. employment has changed over time.

### Figure 3 — Cumulative Real Wage Growth

A time-series index showing the cumulative growth in real median earnings for each occupational group, with 1983 = 100.

The figure also highlights major periods of economic disruption, including the early-2000s recession, the Great
