# Listed Comparables Automation (Python + Excel)

## Overview
Investment analysts build a "listed comparables" workbook to value a company against its publicly
traded peers. Done by hand it takes days per company and normally depends on a paid market-data
terminal.

This project rebuilds that whole deliverable in Python using **only free public data**, and turns it
into one repeatable command. You give it a stock ticker; it identifies the company, builds a worldwide
candidate list, judges every candidate against the screening rules, ranks the peers, pulls about forty
financial metrics for each, and fills a formatted 8-tab Excel workbook with charts.

Four real companies have been run through it end to end, including a German company with no US filings
at all.

---

## Objective
- Reproduce a paid-terminal deliverable from free public sources
- Replace a manual, days-long process with one resumable command
- Keep an analyst in control of the two judgement calls that genuinely need a human
- Never fabricate a number: where free data cannot cover something, say so in the output

---

## Data Sources
All free and public. No paid market-data subscription anywhere in the pipeline.

| Source | Used for |
|---|---|
| SEC EDGAR (`companyfacts` XBRL) | Historical financials for US filers, point-in-time |
| SEC EDGAR filing text | The business-description section of annual reports |
| Wikidata (CC0, SPARQL) | Worldwide company enumeration — companies with no SEC presence |
| Yahoo Finance (`yfinance`) | Prices, market cap, enterprise value, fiscal-year history, FX |
| Gemini API (free tier) | Reading business descriptions into structured characteristics |

Scale: an index of **8,004 US filers**, plus a worldwide layer (181 road-transport companies for a
trucking case, 236 for a logistics case).

---

## Tools & Techniques
- **Python** — 179 modules, ~37K lines (pandas, requests, openpyxl, Excel COM)
- **Financial analysis** — enterprise value, EV/EBITDA, EV/Sales, P/E, EBITDA margin, gross margin,
  revenue CAGR, operating and free cash flow — all recomputed from raw filings rather than taken from
  a vendor
- **XBRL parsing** — de-duplicating restated filings, exact-tag concept selection, a per-company
  EBITDA route chosen by rule
- **Data modelling** — a layered cache (per-case reading through to a shared frozen snapshot), an
  append-only judgement store with full provenance, entity-identity resolution across ID schemes
- **LLM-assisted classification** — 25 business characteristics per company, with a verbatim-quote
  evidence rule and a pinned model + prompt version
- **Excel automation** — writing into a live template without destroying its formulas, charts or styles
- **Testing** — 31 acceptance checks behind a single command, several of them mutation-proven

---

## Methodology — the 14-stage pipeline

```
python -m pipeline run --ticker XYZ
```

**12 stages automatic, 2 analyst checkpoints.** It stops at the first thing it needs and prints exactly
what to produce. Re-running resumes, because a stage counts as done when its output exists on disk —
there is no state file to go stale.

| | Stage | Who |
|---|---|---|
| 1 | Create the case | auto |
| 2 | Build the company profile (industry, geography, segments, business text) | auto |
| 3 | **Write the screening criteria** | **analyst** |
| 4 | Check the criteria are valid (strict linter) | auto |
| 5 | Put the criteria into the workbook | auto |
| 6 | Screen the universe (US filers + worldwide stream) | auto |
| 7 | Work out the numbers (~39 metrics per company) | auto |
| 8 | Put the numbers in the workbook | auto |
| 9 | Judge every company against every criterion | auto |
| 10 | Rank the candidates | auto |
| 11 | **Approve the peer set** | **analyst** |
| 12 | Build the monthly valuation history | auto |
| 13 | Put the history in the workbook | auto |
| 14 | Check the result | auto |

---

## The Deliverable

An 8-tab Excel workbook, generated for any ticker, keeping the template's 20,092 formulas, both
charts, the filter spill, every style and both named ranges:

**Summary** (filterable peer table) · **Football Field** (valuation-range chart) · **Comps** (the peer
grid) · **Comps His** (131 month-ends of EV/EBITDA, EV/Sales and P/E) · **Screen Criteria** ·
**Screening** (the funnel) · **Criteria Matrix** (every company against every criterion) · **Mapping**

The monthly history is **point-in-time**: every figure for a given month uses only what had actually
been filed by that month-end, so a 2018 multiple is never computed from a 2022 restatement.

There is also a web view — four screens (criteria, comparables, football field, trading history)
reading the same numbers as the spreadsheet, served as a static page with Firebase Auth — which makes
Excel an export rather than the system.

---

## Key Results

| Case | What it proved |
|---|---|
| **AbbVie** (US pharma) | The reference build. The funnel reproduces exactly: 8,004 filers → 804 in scope → 765 screened. The finished workbook is provably **regenerable from an empty skeleton plus its own 109,778 values** — so the workbook is a render of the data, not an irreplaceable file |
| **Old Dominion** (US trucking) | The screen generalises to another industry with no code changes: 62 US motor-freight companies, from its own criteria |
| **Deutsche Post / DHL** (Germany) | **No CIK, no SEC filings, no US listing.** Ticker → 369-candidate worldwide screen → 62 judged → analyst-approved roster of 18 → populated grid + 131 months of history. 38+ countries represented, and **22 wrong-company ticker matches refused** |
| **Nestlé** (Switzerland) | Screening criteria assembled **automatically** from machine-read evidence for the first time (6 criteria), then a roster-blind ranking of 17 candidates |

**One command runs every check:** `python -m run_checks` → 31 checks, currently all green.

---

## What I Learned (the hard parts)

These are the problems that actually cost time, and they are more interesting than the plumbing.

- **A lookup that returns something is not a lookup that returned the right thing.** A ticker is only
  unique within an exchange. Matching on ticker alone bound a German meal-kit company to `MMM` and
  credited it with **3M's $25bn of revenue**. A match now requires a US listing *and* name agreement.
  The two failure modes are not symmetric: a missed match is two records to merge later, while a wrong
  match is unrecoverable once a permanent judgement is keyed to it.
- **A US classification code can never describe a foreign company.** An industry rule gated on SIC code
  alone dropped 158 of 240 candidates for having no SIC code at all. Naming both schemes
  (`sic_code OR wikidata_industry`) took the same 240 in and dropped **zero**, with 38 non-US countries
  surviving.
- **EDGAR repeats every annual figure in every restating filing.** Summing rows multiplies a number by
  how many times it was filed. Key by `(period start, period end)` first.
- **A gap in one metric alongside a zero in a sibling that shares its inputs is an extraction bug, not
  missing data.** Following that closed an EV/EBITDA history gap from 30% coverage to 70%.
- **Never predict what you can measure.** A "20 requests per day" API cap was read from a header and
  planned around; a later window served 22. Repeat timeouts on the same nine companies looked like a
  data problem and were actually a 60-second client timeout sitting inside a 23–60 second latency range.
- **"Exit 0 and nothing happened" is its own failure class.** A hardcoded version pin in a scheduled
  wrapper made a daily job report success while doing no work at all.
- **A quote that appears is not a quote that supports.** Checking that evidence is verbatim cannot catch
  a real sentence that backs nothing. Measuring that gap — 34.7% of rejections had a passing quote
  elsewhere in the same text — is what justified rewriting the extraction prompt rather than guessing at
  it.

---

## Design Rules

- **No company name is ever typed into code or a formula.** Peers are the output of rules, never a list
  of names. An analyst may override, recorded with a written reason, the author, the date and the rank
  the company held at the time, so override rot stays visible later.
- **A missing number never silently rejects a company.** It goes to review.
- **Judgements are permanent and append-only**, keyed to the model and prompt version that produced
  them, so answers from two prompt generations can never be averaged into one statistic.
- **Deterministic by default.** Every stage reads frozen snapshots; live network access is an explicit
  opt-in flag, so a re-run is a pure function of its inputs.
- **A failed API call must create no record**, or the junk record owns that slot forever and blocks the
  retry.

---

## Known Limits (disclosed, never filled in)

- **Forward estimates are absent from free data** and stay permanently blank. A paid terminal carries
  analyst consensus; nothing free does.
- **Monthly history is EDGAR-only**, so a non-US peer set has real gaps — 6 of DHL's 18 roster members
  have none. That is a data-source problem, not a code one.
- **Coverage beats cleverness.** Measured across 990 companies: revenue 482, five-year growth 194,
  EBITDA growth 1, revenue mix 0. No ranking formula overcomes a missing input.
- **Two stages need a human** by decision, not by accident: writing the screening criteria and approving
  the final peer set. Roughly a couple of hours of analyst time per company.

---

## Output Preview

**Football Field** — implied equity value by peer category (curated peers, sector context bands, the
subject's own 24-month trading range) against the subject's current equity value. Title, categories and
axis scale all follow the subject, so the chart is not shaped for any one industry.

![Football Field](FootballField.png)

**Monthly valuation history** — 131 month-ends of EV/EBITDA, point-in-time. Note the title: it states
that 10 of 12 peers are drawn and names the two that have no history, rather than drawing a smooth line
through data that does not exist.

![Trading History](TradingHistory.png)

---

## Files
The pipeline runs against a private repository (it contains a firm's workbook template and cached
filings). Code walkthrough available on request.

---

## Status
Working — 4 companies run end to end, 31 automated checks green. Automatic criteria writing and
automatic peer selection are the stages currently being generalised.
