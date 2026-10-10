# Commercial Real Estate Segmentation (DataFest 2025)

## Overview
This team project was developed during ASA DataFest 2025, a national data analysis competition. Using commercial real estate lease data from Savills, we answered one question: where and when should technology and financial services firms lease office space?

> **The code in this folder is a reconstruction that runs on synthetic data.**
> The original R code was lost, and the Savills data had to be deleted after the event for confidentiality. The scripts here were rebuilt afterwards from the team's working notes, saved code snippets and the final presentation. They run on generated data that has the same column names as the original files but invented values, so their output does not match the presentation. The real results are in the presentation.

## Files

| File | What it is |
|---|---|
| [Yokies DataFest Presentation.pptx](https://github.com/linhnguye237/linh-nguyen-portfolio/blob/main/projects/datafest-real-estate/Yokies%20DataFest%20Presentation.pptx) | Final presentation, with the results from the real data |
| [analysis.Rmd](analysis.Rmd) | Reconstructed analysis as an R Markdown notebook |
| [analysis.R](analysis.R) | The same analysis as a plain R script |
| [make_synthetic_data.R](make_synthetic_data.R) | Generates the synthetic input files the analysis reads |

## How to Run
Requires R with `tidyverse`, `cluster` and `factoextra` (plus `rmarkdown` to knit the notebook).

```
Rscript make_synthetic_data.R   # writes three synthetic CSVs to data/
Rscript analysis.R              # writes charts and tables to output/
```

Or open `analysis.Rmd` in RStudio and knit it after running the first command.

## Dataset
- **Original:** lease-level office transactions from Savills (rent, leased square footage, building class, industry, city and market, by quarter), a market-level occupancy file, and labor force, employment and unemployment figures per city. None of it is in this repository.
- **In this folder:** synthetic stand-ins for those three files, created by `make_synthetic_data.R`.

## Tools & Techniques
- R (dplyr, tidyr, ggplot2, cluster, factoextra)
- K-means clustering with the elbow method
- Chi-square test of independence with residual analysis
- One-way ANOVA and paired t-test
- Data visualization

## Methodology

1. **Data preparation**
   - Joined leases to market occupancy by year, quarter and market
   - Standardized the three clustering features: class-level rent, average occupancy and leased square footage

2. **Clustering (where)**
   - Used the elbow method to choose the number of clusters, then fit k-means with k = 6
   - Labelled each cluster from its average rent, occupancy and lease size: Hot Spot, Value Cluster, Distressed, Overpriced, Transitional Large Leases, Mega Leases
   - Took the seven cities with the most leasing in the three main clusters and grouped each by its dominant cluster

3. **Industry and economic context (where)**
   - Chi-square test of whether industry (technology vs. finance) is independent of cluster type
   - Labor force, employment and unemployment trends for each city, 2018 to 2024

4. **Timing (when)**
   - Compared average occupancy by quarter in each city
   - One-way ANOVA across quarters, and a paired t-test of Q1 and Q4 against Q2 and Q3

## Key Findings
These come from the original analysis on the real data, as shown in the presentation. The scripts in this folder will not reproduce the numbers.

- Office leases separated into six segments, from premium high-rent markets with strong demand to low-rent, low-occupancy ones
- The seven cities fell into three groups: New York and San Francisco (Hot Spot), Houston, The Woodlands and Austin (Value Cluster), Los Angeles and Philadelphia (Distressed)
- Industry and cluster type are not independent: finance firms were over-represented in Hot Spot markets, technology firms in Value and Distressed markets
- Occupancy tended to be lower in Q2 and Q3, which points to those quarters as the better time for tenants to negotiate

## What Is Reconstructed
Comments in the scripts mark each part as `ORIGINAL` (copied from surviving notes) or `GUESS` (filled in because nothing surviving settles it). The main guesses are:

- The random seed and number of starts for k-means
- Which rows were dropped before clustering
- The exact scope of the chi-square test
- The cluster labels, which the team assigned by hand and the script assigns by rule

## Business Impact
- Gives tenants a way to match a city to their priorities: prestige, cost, or scale
- Ties location advice to industry patterns and local labor market conditions
- Adds a timing recommendation based on seasonal occupancy

## Status
Completed. Presentation is original; code is a reconstruction on synthetic data.
