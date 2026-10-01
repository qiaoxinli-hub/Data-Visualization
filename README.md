# Data-Visualization

## Project Overview —— Occupational Structure and Wage Changes in the U.S. Labor Market

This project examines how the occupational structure of the U.S. labor market has changed over the past four decades and how real earnings have evolved across different types of occupations.

Using IPUMS Current Population Survey (CPS) microdata from 1983 to 2023, the project studies long-run changes in employment shares and real median earnings across four broad occupational groups.

Besides, the analysis is descriptive and focuses on identifying possible patterns in the U.S. labor market through survey-weighted statistics and data visualization.

## Research Questions

The project focuses on three main questions:

**1. How has the occupational structure of the U.S. labor market changed from 1983 to 2023?**
**2. How have real median wages changed across different occupational groups?**
**3. Do employment and wage patterns show evidence of long-run job polarization?**

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

**Because the CPS microdata are large, the original `.dat.gz` and related extract dataset are not included in this GitHub repository.**

## Sample Definition

The analysis focuses on:

* Civilians aged **25–64**
* Employed individuals
* Individuals with positive and non-missing wage income
* Individuals with valid occupation codes
* Four broad occupational groups

In the data-cleaning step, observations with invalid or non-usable wage values and invalid occupation codes are removed. The age range of 25–64 is used to focus on the prime working-age population and reduce the influence of individuals who are more likely to be in school or approaching retirement.

## Survey Weights

The CPS survey weights (`ASECWT`) are used throughout the analysis to produce population-representative estimates. The survey design is constructed using the srvyr package:

cps_svy <- cps_cleaned %>%
  as_survey_design(weights = ASECWT)

Survey weights are important because each CPS respondent represents a different number of people in the U.S. population. Therefore, the employment shares and median earnings reported in this project are survey-weighted estimates, rather than simple unweighted sample statistics.

## Occupational Classification

Occupations are grouped into four broad categories based on task characteristics:

| Occupational Group    | Description                                                                              |
| --------------------- | ---------------------------------------------------------------------------------------- |
| Non-Routine Cognitive | Managers, professionals, and technicians                                                 |
| Routine Cognitive     | Sales, administrative, and clerical occupations                                          |
| Routine Manual        | Machine operators, repair, construction, transportation, and assembly occupations        |
| Non-Routine Manual    | Food service, personal care, household services, security, and other service occupations |

The groups are assigned using ranges of the OCC1990 occupation code:

Non-Routine Cognitive: OCC1990 3–235

Routine Cognitive: OCC1990 243–389

Non-Routine Manual: OCC1990 403–469

Routine Manual: OCC1990 503–889

## Excluded Occupations

Agriculture, forestry, fishing, military, and unclassified occupations are excluded from the four-group analysis. That's because they can't be consistently assigned to one of these four task-based categories. Therefore, the four groups do not represent all occupations in the sample.

## Wage Adjustment

Nominal wage income is converted into **real 2023 dollars** using the annual U.S. Consumer Price Index for All Urban Consumers (CPI-U).

The 2023 CPI is used as the base year:

```text
Real Wage =
Nominal Wage × (CPI in 2023 / CPI in Year t)
```

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

For each year and occupational group, the analysis calculates the survey-weighted median of inflation-adjusted annual wage income.

Median earnings are used instead of mean earnings because the median is less sensitive to extremely high earnings.


### Wage Growth Index

To compare long-run wage growth, 1983 is used as the base year:

```text
Wage Index =
(Median Real Wage in Year t /
 Median Real Wage in 1983) × 100
```

Therefore, an index value of 100 represents the 1983 wage level, and an index value of 120 represents a 20% increase over the 1983 level.

## Visualizations

The analysis produces four main figures.

### Figure 1 — U.S. Job Polarization

A continuous time-series chart showing changes in the employment share of the four occupational groups from 1983 to 2023.

### Figure 2 — Occupational Structure

A stacked area chart showing how the composition of U.S. employment has changed over time.

While Figure 1 emphasizes the individual trends of each occupational group, Figure 2 emphasizes the overall structure of employment and the relative contribution of each group.

### Figure 3 — Cumulative Real Wage Growth

A time-series index showing the cumulative growth in real median earnings for each occupational group, with 1983 = 100.

The figure tracks how the purchasing-power-adjusted median earnings of each group changed over the 40 years.It also highlights major periods of economic disruption, including the early-2000s recession, the Great

### Figure 4 — Changes in Real Median Earnings
A dumbbell chart comparing real median annual earnings across the four occupational groups in 1983 and 2023, expressed in 2023 dollars.

The figure shows both the median earnings level in 2023 and the percentage change in real median earnings over the past 40 years.

## Project Structure

The repository is organized into the following main components:

- **`README.md`**  
  Provides an overview of the project, including the research questions, data source, sample selection, occupational classification, methodology, visualizations, and limitations.

- **`blog3.qmd`**  
  Contains the main Quarto source file for the project. It includes the data analysis, written discussion, and code used to generate the visualizations.

- **`blog3.html`**  
  Contains the rendered HTML version of the Quarto blog post.

- **`cps_00001.xml/`**  
  Contains the data files or data-related materials used in the project. The original IPUMS CPS microdata are not included because the data are accessed through IPUMS.

- **`data extraction.R/`**  
  Contains the R scripts used for data extraction, cleaning, variable construction, statistical calculations, and visualization.

- **`figures/`**  
  Contains the four main figures used in the analysis:
  - `figure1.png` — U.S. job polarization
  - `figure2.png` — Occupational structure
  - `figure3.png` — Cumulative real wage growth
  - `figure4.png` — Changes in real median earnings
