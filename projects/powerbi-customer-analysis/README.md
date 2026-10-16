# Customer Segmentation Dashboard (RFM Analysis)

## Overview
This project presents a 3-page Power BI dashboard that analyzes customer behavior using RFM (Recency, Frequency, Monetary) methodology. The goal is to segment customers, evaluate churn risk, and support data-driven CRM and marketing strategies.

---

## Objective
- Understand customer purchasing behavior
- Identify high-value and at-risk customer segments
- Support targeted marketing and retention strategies

---

## Dataset
- Source: CRM & ERP systems (KPIM / KM2)
- Transactional data up to 2022
- Includes customer transactions, revenue, and behavioral attributes

---

## Tools & Techniques
- Power BI
- Power Query (data cleaning and transformation)
- DAX (calculated measures and KPIs)
- RFM Analysis (Recency, Frequency, Monetary)

---

## Dashboard Structure

### 1. Overview
- Monthly revenue trend and volatility (2020–2022)
- Key KPIs:
  - Total customers: 18.36K
  - Total revenue: 17.91bn
  - Average recency: 100 days
  - Average frequency: 1
  - Average monetary: 975.39K
- Customer distribution across segments

### 2. Customer Profile
- Customer segmentation by loyalty groups (e.g., high-value, churned, dormant)
- Demographic analysis:
  - Gender distribution
  - Age distribution
  - Income distribution
  - Occupation breakdown
- Segment-level behavioral patterns

### 3. Behavioral & Diagnostic Analysis
- Promotion effectiveness by customer segment
- Discount usage patterns across segments
- Revenue comparison: promotional vs non-promotional
- Churn risk metrics:
  - Revenue at churn risk: 2.69bn (true figure 4.05bn; see Promotional Playbook)
  - Customers at risk: 3.65K (true figure 4,818; see Promotional Playbook)
  - Discount dependency index: 2.05%

---

## Key Insights

- Revenue shows volatility across periods, indicating unstable performance trends  
- A significant portion of customers falls into mid- to low-engagement segments  
- High-value customers contribute disproportionately to total revenue  
- Customers at churn risk represent a large revenue exposure  
- Discount-heavy strategies are linked to certain segments, suggesting dependency  

---

## Business Recommendations

- Prioritize retention strategies for high-value and at-risk customers  
- Reduce over-reliance on discounts by improving value propositions  
- Develop targeted campaigns based on customer segments  
- Focus on increasing purchase frequency for low-engagement segments  

---

## Features
- Interactive filters (time, segment, store)
- Dynamic KPIs and segment-level metrics
- Drill-down capabilities across dashboard pages
- Multi-page analytical storytelling (Overview → Profile → Diagnostics)

---

## Promotional Playbook
A 14-slide follow-up deck that turns the dashboard's segments into a spend plan: which of the 8 RFM segments to grow with perks, which to win back and in what order, and four fixes to how promotions are planned and measured.

The dashboard was submitted as-is, so the deck documents its known issues rather than fixing them:
- **Confirmed bug:** the churn-risk measures filter on "Cooling Down Customers" (no hyphen), which silently drops that segment. The true figures are 4,818 customers / 4.05bn, not the 3.65K / 2.69bn shown.
- **Data limitations:** no sale falls inside any promotion's validity dates (all 16 run 2010–2014; transactions are 2020–2022, and 8 promotions were never used), and the discount tiers' min/max quantities don't match the actual sales.
- **Measurement gaps:** promotion effectiveness reports revenue, not profit, and the single average recency hides segments ranging from 15 to 250 days.
- **Presentation slips:** one chart titled "Occupation Distribution" actually shows education level, and some visuals clip segments behind internal scrolling.

An appendix slide lists every figure in the deck, recalculated from the .pbix's own DAX and tables, with whether it matches, is a dashboard bug, or was revised.

- [Download Promotional Playbook (GitHub)](https://github.com/linhnguye237/linh-nguyen-portfolio/blob/main/projects/powerbi-customer-analysis/RFM_Promotional_Playbook.pptx)

---

## Files
- [Download DashBoard (GitHub)](https://github.com/linhnguye237/linh-nguyen-portfolio/blob/main/projects/powerbi-customer-analysis/RFM_Updated_2.pbix)
- [Download Promotional Playbook (GitHub)](https://github.com/linhnguye237/linh-nguyen-portfolio/blob/main/projects/powerbi-customer-analysis/RFM_Promotional_Playbook.pptx)

## Dashboard Preview
![Introduction](Intro.png)
![Overview](Overview.png)
![Customer Profile](Customer.png)
![Behavior Analysis](Diagnostics.png)

---

## Status
Completed 

