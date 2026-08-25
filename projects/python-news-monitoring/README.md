# Vietnam News Monitoring Pipeline (Python)

## Overview
This project replaces the news gathering behind a weekly institutional research note. An investment
team publishes a Vietnam market update every Friday, and one section of it is a curated list of
outside articles worth reading. That section was produced by a no-code workflow that scraped four
sites once a week and passed the text to a paid language model.

Here it runs as a Python pipeline on a schedule. Ten sources are swept every morning in English and
Vietnamese, judged against criteria derived from the team's own two-year publishing record, and
written into one Excel workbook and a private dashboard.

In production since 5 August 2026. The store holds 1,564 articles kept and 2,469 rejected across 58
daily runs.

---

## Objective
- Replace a weekly paid scraping workflow with a daily run that costs nothing per article
- Derive the selection criteria from what the team actually published, not from what it says it wants
- Cover Vietnamese-language sources, which the previous workflow did not read at all
- Keep a source's volume from deciding the reading list
- Report what each run failed to collect, instead of presenting a partial sweep as a complete one

---

## Dataset
- Source: 10 live news sources, 4 Vietnamese and 6 English, read through RSS feeds where they exist
  and XML sitemaps where they do not
- 1,564 articles collected between 1 and 25 August 2026, with 2,469 rejections kept alongside them
- Criteria built from 597 articles selected across 90 past issues of the note, May 2024 to July 2026
- Every article carries a priority band, one of thirteen categories, an extracted entity and figure
  set, and the run that found it
- All sources are free and public. No paid market data feed and no API key is used anywhere in the
  pipeline.

---

## Tools & Techniques
- Python (feedparser, requests, BeautifulSoup, openpyxl, SQLite): 26 modules, about 8,700 lines
- Configuration-driven design (YAML): sources, criteria, watchlist and output are all config, so
  pointing the tool at a different topic means writing a config rather than changing code
- Rule-based text classification (a four-layer filter, no model and no API key)
- Cross-language deduplication on entities and quantities
- Ranking and constrained selection (dominance ceiling, reserved places, tie-breaks)
- Data modeling (append-only SQLite store, page cache, URL canonicalisation)
- Excel automation (a workbook that grows, with one column the tool is forbidden to write to)
- Web publishing (Firestore upload, Vercel-hosted viewer behind a domain-restricted Google sign-in)
- Automated testing (798 checks across 18 suites, no network and no API key)
- Scheduled operation on Windows Task Scheduler, with backups through SQLite's own backup API

---

## Methodology

1. Ask each source what it has
- About 14 small requests, nothing downloaded yet
- Feeds are never cached, because a feed is a statement about what exists right now

2. Drop what is already known
- The store holds every URL ever collected, including ones previously rejected, so nothing is
  reconsidered and nothing is shown twice

3. Collapse the same story reported twice
- Compares proper nouns, tickers and quantities with their unit and magnitude, not headlines
- This catches the same 450MW solar plant reported in English as "Tay Ninh" and in Vietnamese as
  "Dau Tieng 5", because VND7.77 trillion and "7.774 tỷ" are the same figure written two ways

4. Download the survivors
- 30 to 60 pages, 1.5 seconds apart, cached so no page is ever fetched twice

5. Judge it
- A gate (is there a real Vietnam connection), a qualifying test (a deal, a sector read, a policy
  change, results, or a risk event), a priority band, and an exclusion list
- Then a category for browsing, and an evidence pass that demotes commentary and lifts transactions

6. Select the reading list
- Rank, apply a dominance ceiling, and write the period's own workbook

The daily run is one scheduled task: backup, sweep, digest, reading list, and the upload the
dashboard reads. It runs at 07:30 Vietnam time, so a run covers the previous Vietnamese day complete.

---

## What It Produces
- **`news_log.xlsx`** — one workbook that grows, newest at the top. Date, source, title, summary,
  priority, link and a Notes column that belongs to the reader. Nothing the tool does ever writes to
  Notes, and there is a test that types a note, runs a review over that row, and checks it survived.
- **A "Run log" tab** — one row per morning: which sources answered, how many articles arrived, what
  was refused, what failed, and what `robots.txt` declined. The tab turns red on a warning.
- **A reading list for any period** — a day, a range, or a week, each written to its own small
  workbook. Assembled from the store, so it is instant and can be re-run as often as needed.
- **A private dashboard** — the day's articles grouped by category, behind a Google sign-in
  restricted to the firm's domain, because the articles are publishers' copyright.

---

## Results
- Runs unattended. 58 daily runs, with backup, sweep, publication and upload completing with nobody
  present.
- Coverage roughly doubled. The previous workflow read four English sites once a week; this reads ten
  sources every morning, four of them Vietnamese.
- 1,564 articles kept and 2,469 rejected, with the rejections stored rather than discarded so the
  cost of the filter can be sampled and argued with.
- Priority bands across the store: 317 High, 449 Medium, 338 Low, 460 judged not worth reading.
- The reading list spans four to seven sources on a normal weekday, from a feed that is 61% one wire.
- 798 automated checks pass, many of them written for bugs that were real during the build.

---

## Key Insights

- **Volume and value point in opposite directions.** CafeF supplies 61% of everything collected and
  appears in 2% of what the team has ever selected. DealStreetAsia is 1% of collection and 25% of the
  published record. A list ranked on merit alone is a list ranked by who publishes most.
- **Variety has to be a ceiling, not a quota.** Ranking purely on merit produced a top ten that was
  eight articles from one wire. A cap set to the smallest number the day's supply allows fixes it
  without ever padding: a window with five articles gives five, and no article is included *because*
  of its source, only deferred because of it.
- **Scoring what is readable is itself a bias.** Content ranking can only score text the tool can
  fetch, which favours exactly the sources the firm's own rules rank lowest. The pipeline records the
  exposure rather than hiding it, and reserves a place for the source that cannot win one.
- **The filter cannot see advertorial.** A scan of one source's feed put 17 items through the gate;
  three were sponsored content and two were rated High. Advertorial names a real company and carries
  a real figure, so it is written to pass every test the filter has. Detection had to come from
  register and sourcing instead, and it demotes rather than deletes.
- **Keyword priority is not trustworthy on its own.** Left to the rules, an airport operator's
  donation to a war cemetery ranked High. Priority is only worth sorting on once the rows have been
  read properly, which is why the review step sits before the reading list rather than after it.
- **A scheduled task can report success while doing nothing.** Three separate runs exited zero after
  a laptop slept mid-run, a stale file, and a truncated prompt. The checks now ask the artifact what
  happened rather than asking the exit code.
- **Two years of evidence is worth more than an opinion about sources.** The Economist, the New York
  Times and Tech in Asia together account for 4 of 597 selections, or 0.7%, which is worth knowing
  before spending any further effort on getting past their crawler policies.

---

## Business Impact
- Removes a paid no-code scraping workflow and its language model credits from the weekly process.
  The pipeline runs locally with no API key and no monthly bill.
- Turns a weekly gather into a daily one, so a story is available on the morning it is published
  rather than on the Saturday after it.
- Adds the Vietnamese-language sources the previous workflow could not read, which is where most of
  the domestic corporate news actually breaks first.
- Makes the reading list defensible. Selection comes from written criteria derived from the
  publishing record, and every run states which sources refused it, so a thin week is visible as a
  thin week rather than as a quiet one.
- Protects work that nothing regenerates. Re-running does not bring back a window that has rolled out
  of the feeds, and no scraper rewrites a summary a person wrote, so the store, the log and the
  reader's own notes are backed up every morning.

---

## Features
- One command per run, resumable and safe to repeat: only ever adds what is new
- Ten sources in two languages, added or removed in config rather than in code
- Cross-language deduplication against both the batch and the whole store
- A reading list for any day, range or week, assembled without re-scraping
- Selection that never pads and never lets one publisher own the list
- An evidence pass that demotes commentary and lifts transactions, and never drops either
- Manual ingestion for articles saved by hand, kept full-text and searchable after the page is gone
- Coverage reporting on every run: pages refused, failed, and skipped per `robots.txt`
- 798 automated checks behind one command, plus a 16-check live self-test

---

## Being a Good Citizen
The tool sends a real user agent, waits 1.5 seconds between requests, caches article pages so nothing
is fetched twice, and honours `robots.txt`. It does not impersonate a browser to get past a site that
has deliberately blocked automated clients, and it does not read paywalled content through an archive
proxy.

Two publishers refuse AI crawlers, so only their headlines and links are taken, no article page is
ever downloaded, their text never reaches a model, and their priority is capped. Articles stay out of
version control, and the dashboard sits behind a sign-in, because the text belongs to its publishers.

---

## Limitations
- Reading and scoring the day's articles is a judgement, not a cron job. Until the day is scored the
  list falls back to the firm's written source rules, and the page says on its face that it did.
- One source refuses most of its article pages, so it is ranked on headlines and holds a reserved
  place rather than competing on text
- Two configured sources are disabled and disclosed: one publishes a feed with no date element, the
  other refuses all automated clients
- The daily task has to run while the user is logged on, because publishing uses the user's own
  credentials. Service account keys are blocked across the organisation, so this is a constraint to
  work within rather than a shortcut not taken.

---

## Files
The pipeline runs in a private repository, as the store holds publishers' copyrighted article text
and the configuration holds the firm's own selection criteria. A code walkthrough is available on
request.

---

## Status
In production, running daily since August 2026. In progress of automating the one step that is still
a judgement: reading and scoring the day's articles before the list is built.
