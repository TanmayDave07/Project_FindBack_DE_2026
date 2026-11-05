# Spotify Music Streaming Database: DBMS Project

**Course:** Database Management Systems · **Year:** B.Tech 2nd year · **Team size:** 4
**Database:** PostgreSQL 15 or newer · **Final submission:** Mon 23 Nov 2026
**Topics used:** Data types & constraints · Keys & relationships · Normalization · Query execution plans · Indexing · Query optimization · VACUUM/ANALYZE · Partitioning & sharding

## Files in this folder

| Path | What it is |
|------|------------|
| `README.md` | This project brief |
| `seed_data.zip` | 10 CSV files (250,000 streams): the only input for Phase 2. Unzip it to get `seed_data/` |
| `queries/workload_30.sql` | The 30 queries for Phase 3 (do not edit) |
| `benchmarks/run_benchmark.sh` | Timing script: 3 runs per query, average, raw plans saved |
| `CHECKPOINTS.md` | Checkpoint dates and the files each one needs (DE and AP repos) |

**Getting started:** **clone this repository and push it into your team's DE repo** (the DE repo you submitted in the form); the steps are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Keep the structure shown in [Repository structure](#repository-structure-submit-exactly-this). Unzip `seed_data.zip` inside your project folder, but don't commit the CSV files. Deadlines are in [`CHECKPOINTS.md`](CHECKPOINTS.md). Then begin with Phase 1.

---

## Team details (fill in before you start)

| Role | Name | Enrollment No. | GitHub Username |
|------|------|----------------|-----------------|
| Group Lead | Yashra Panghal| 2501010526 | yashrajhuntmi7 |
| Member 2 | Tanmay Dave | 2501010475| TanmayDave07 |
| Member 3 | Ajay Kumar | 2501010040 | AjayKumar026 |
| Member 4 | Harsh Tomar | 2501010725 | HarshNST |Markdown Preview GitHub Styling

**Team No.:** T0068 · **Section:** E · **Repository URL:** https://github.com/TanmayDave07/Project_FindBack_DE_2026 

---

## How this project works

| Phase | What you do | You submit | Counts toward | Marks |
|-------|-------------|------------|---------------|------:|
| 1 | Understand the problem statements | `docs/01_problem_understanding.md` | Query Execution | 2 |
| 2 | Work out the database schema **from the seed data** and load it | `sql/01_schema.sql`, `sql/02_load_data.sql`, `docs/02_schema_design.md` | Query Execution | 5 |
| 3 | Run the **30 given SQL queries** and record their execution time | `docs/03_baseline_timings.md`, `benchmarks/results/baseline/` | Query Execution | 3 |
| 4 | Optimize the queries and record the new times | `sql/05_indexes.sql`, `sql/06_optimized_queries.sql`, `docs/04_optimization_report.md`, `benchmarks/results/optimized/` | Code Optimization | 16 |
| 5 | Scalability test on the **large dataset** (given later by faculty) and final report | `docs/05_scalability_report.md`, `benchmarks/results/large/` | Code Optimization | 14 |
| | **Total** | | | **40** |

---

## Phase 1: Problem statements

Spotify streams music to free and paying listeners. **Artists** release **albums** (albums, EPs, singles, compilations) made of **tracks**; a track can have a primary artist and featured artists, and every recording has an international **ISRC** code. Listeners stream tracks from playlists, albums, artist pages, radio or search; a stream of **30 seconds or more** earns royalties. Listeners like tracks, follow artists and build playlists—some are public, some collaborative. You have joined the Spotify India data team.

The current database was put together quickly by an earlier team. It has **no documented schema** (only data exports survive), and the product teams are complaining:

| # | Problem reported | Team | Related queries |
|---|------------------|------|-----------------|
| P1 | "**Artist pages, album pages and playlists** open slowly for popular artists." | Listener app | R01, R02, R05 |
| P2 | "**Search**, **Recently played** and **Liked Songs** lag for heavy listeners." | Listener app | R03, R04, R06, W01, W02 |
| P3 | "Artists want **Spotify for Artists** stats (skip rates, fans-also-like, listeners) in real time." | Artists | R08, R15, R16, W04 |
| P4 | "**Royalty** reports (30-second rule) and **rights lookups by ISRC** must be fast and exact." | Royalties / Labels | R07, R21, R24, W05 |
| P5 | "The curation team's "**public playlists never played**" report always comes back **empty**." | Curation | R13 |
| P6 | "**Wrapped**, **Release Radar** and **new-release discovery** jobs take too long." | Personalization | R09, R11, R25 |
| P7 | "**Compliance** must check explicit tracks streamed by minors." | Compliance | R12 |
| P8 | "Playlist features (adding tracks, collaborative stats, duplicate clean-up) are slow." | Playlists | R14, R22, W03 |
| P9 | "Growth and platform analytics (upsell list, daily streams, offline share, hourly patterns, artist report) time out, and streams will grow **20×**." | Growth / Analytics | R10, R17, R18, R19, R20, R23 |

**Your job:**
1. Rebuild a correct, well-constrained schema from the data exports (Phase 2).
2. Measure how the 30 most important queries perform today (Phase 3).
3. Make them fast **without changing their results** (Phase 4).
4. Prove the database will survive next year's growth (Phase 5).

**Deliverable for Phase 1** (`docs/01_problem_understanding.md`, at most 1 page):
- For each problem P1–P9, write in your own words what the business needs and which **stakeholder** is affected (listener, free vs Premium user, artist (Spotify for Artists), label/rights holder, curation team, royalties/finance, compliance, growth).
- Classify each problem as **customer-facing / real-time** or **reporting / analytics**. This decides your performance targets later.
- List any assumptions you make.

---

## Phase 2: Work out the schema from the seed data

You receive **`seed_data.zip`**. Unzip it to get a folder **`seed_data/`** with 10 CSV files, a real export of the production data:

| File | Rows | What it contains |
|------|-----:|------------------|
| `artists.csv` | 3,000 | Artists and bands |
| `albums.csv` | 12,000 | Albums, EPs, singles and compilations |
| `tracks.csv` | 67,808 | Recordings (tracks) on each album |
| `track_artists.csv` | 77,489 | Artists on each track (primary and featured) |
| `users.csv` | 30,000 | Listeners |
| `playlists.csv` | 10,000 | User playlists |
| `playlist_tracks.csv` | 120,004 | Tracks in each playlist, in order |
| `streams.csv` | 250,000 | Every stream from 1 Jan 2025 to 30 Jun 2026 |
| `liked_tracks.csv` | 58,533 | Liked Songs of each user |
| `artist_follows.csv` | 69,901 | Which user follows which artist |

The first line of every file is the header (column names). Here are the headers and the first rows of each file:

**artists.csv**
```
artist_id,artist_name,country_code,primary_genre,is_verified,monthly_listeners,created_at
1,Vivaan Arora,IN,Indie,t,120,2014-07-15 22:58:35+05:30
2,Aditya Arora,IN,Punjabi,t,84,2013-11-24 07:16:45+05:30
```

**albums.csv**
```
album_id,artist_id,album_title,album_type,release_date,label,upc
1,1696,Monsoon Dreams,SINGLE,2024-01-18,Tips,100000007919
2,2993,Echoes Dreams,EP,2020-08-30,Tips,100000015838
```

**tracks.csv**
```
track_id,album_id,disc_no,track_no,title,duration_ms,explicit,isrc,popularity
1,1,1,1,Lost in Love,97956,f,INASA2400001,92
2,1,1,2,Ilahi,105875,f,INASA2400002,93
```

**track_artists.csv**
```
track_id,artist_id,role
1,1696,PRIMARY
2,1696,PRIMARY
```

**users.csv**
```
user_id,email,display_name,country_code,birth_date,subscription,created_at
1,vivaan.sharma1@gmail.com,Vivaan S.,AE,2005-11-13,PREMIUM,2020-12-12 09:42:11+05:30
2,aditya.sharma2@gmail.com,Aditya S.,GB,1981-01-11,DUO,2016-09-27 11:32:23+05:30
```

**playlists.csv**
```
playlist_id,owner_user_id,name,is_public,is_collaborative,created_at
1,12930,Road Trip,f,f,2021-08-16 06:10:45+05:30
2,17307,Chill Vibes,t,f,2022-12-26 04:25:15+05:30
```

**playlist_tracks.csv**
```
playlist_id,position,track_id,added_by_user_id,added_at
1,1,71,12930,2022-12-05 00:00:00+05:30
1,2,9478,12930,2021-08-18 06:10:45+05:30
```

**streams.csv**
```
stream_id,user_id,track_id,started_at,ms_played,platform,source_type,playlist_id,skipped,offline
1,15233,13869,2025-01-01 00:00:00+05:30,251995,SPEAKER,PLAYLIST,6375,f,f
2,642,55762,2025-01-01 00:03:08+05:30,256106,ANDROID,ALBUM,,f,f
```

**liked_tracks.csv**
```
user_id,track_id,liked_at
1,42854,2026-01-13 17:23:49+05:30
1,67125,2025-03-01 11:54:51+05:30
```

**artist_follows.csv**
```
user_id,artist_id,followed_at
1,90,2022-04-20 06:27:09+05:30
1,200,2023-11-01 16:54:57+05:30
```

Open the files yourself (a spreadsheet, `head`, or `SELECT` after a quick load into a scratch table) and study the data carefully. **Nobody will give you the CREATE TABLE statements.** Working them out *is* the task.

### 2.1 What you must identify (for every table)
1. **Table name and column names.** Use exactly the file names and CSV headers. The 30 queries depend on them.
2. **Data type** of every column. Choose the *right* type, not just `TEXT` everywhere. Think about money, timestamps with a time-zone offset, yes/no columns, small whole numbers, decimals and short codes.
3. **Primary key.** Is it one column, or a combination? (Look closely at `track_artists`, `playlist_tracks`, `liked_tracks`, `artist_follows`, and what identifies a track inside an album.)
4. **Foreign keys.** Which column points to which table? What should happen **ON DELETE** (CASCADE, RESTRICT or SET NULL), and why?
5. **NOT NULL vs NULL.** Some columns are empty in some rows. Find out **when** and **why**, and decide which columns must never be empty. Why do some streams have no `playlist_id`? Compare it with `source_type`.
6. **UNIQUE** columns (natural candidate keys such as emails, phone numbers, codes and handles).
7. **CHECK constraints.** Write at least **12** that the data obeys and the business needs. Look for formats (ISRC, UPC, country code), allowed values (album types, roles, subscriptions, platforms, sources), ranges (durations, popularity, birth dates), and rules tying columns together (a playlist id only for playlist streams, a collaborative playlist can't be public, a skipped stream is short).
8. **Relationships and cardinalities** (1:1, 1:N, M:N). Draw the **ER diagram** (image + Mermaid code).
9. **Normal form.** Show that each table is in 3NF/BCNF (list its functional dependencies). Point out any column that is *derived or redundant* (hint: `artists.monthly_listeners`; `streams.skipped` vs `ms_played`; the primary artist in `track_artists` vs `albums.artist_id`) and say whether keeping it is justified.

### 2.2 Rules for your schema
- Create every table in a schema named **`spotify`**: `CREATE SCHEMA spotify;` and `SET search_path TO spotify;`
- In this phase create **only constraints**: PK, FK, UNIQUE, NOT NULL, CHECK. **Do not create any other index yet.** (PostgreSQL automatically indexes PRIMARY KEY and UNIQUE columns; that's allowed. Note which indexes exist.) Your baseline in Phase 3 must reflect a database *without* tuning.
- Your constraints must accept **all** rows of the seed data. If a load fails, either your constraint is wrong or you found a data problem. Explain which in your design doc.

### 2.3 Load the data
Write `sql/02_load_data.sql` using `\copy`, loading tables in the right order (parents before children):

```sql
SET search_path TO spotify;
\copy artists FROM 'seed_data/artists.csv' WITH (FORMAT csv, HEADER true)
-- ... the other tables, in an order that satisfies your foreign keys
ANALYZE;
```

Then verify the row counts match the table above, and run at least **3 integrity checks** of your own (e.g. "nobody streamed a track before its album was released", "ms_played never exceeds the track duration", "every track has exactly one PRIMARY artist"). Paste the results into `docs/02_schema_design.md`.

### Phase 2 deliverables
- `sql/01_schema.sql`: runs top-to-bottom on an empty database without errors
- `sql/02_load_data.sql`: loads all 10 files without errors
- `docs/02_schema_design.md`: data dictionary (table · column · type · constraint · *why*), ER diagram, FDs and normal form per table, integrity-check results, and every data problem you found

---

## Phase 3: Run the 30 queries and record the time

The file **`queries/workload_30.sql`** contains **30 queries**: 25 reads (`R01`–`R25`) and 5 writes (`W01`–`W05`). They're also listed in the [Appendix](#appendix-the-30-queries). **Do not modify them.** If a query fails, your schema doesn't match the seed data; fix the schema, not the query.

### 3.1 How to measure (everyone must use the same method)
- Run each query with `EXPLAIN (ANALYZE, BUFFERS)` and read the **`Execution Time`** at the bottom.
- Run each query **3 times** and record the **average** of the three `Execution Time` values. Keep all three runs in the raw plan file.
- Write queries (`W01`–`W05`) must be measured inside `BEGIN; … ROLLBACK;` so the data does not change.
- Close other heavy applications while measuring, and use the **same laptop** for Phase 3 and Phase 4.

The helper script does all of this for you:
```bash
./benchmarks/run_benchmark.sh <your_database> baseline
# → benchmarks/results/baseline/summary.csv   (avg, median, min, max, scan types)
# → benchmarks/results/baseline/R01.txt …     (full plans of all 3 runs)
```
> ⚠️ One of the 30 queries takes **several seconds** on the seed data. That's intentional. Let it finish, and don't skip it.

```drawio width=800
<mxfile>
  <diagram id="default" name="Page-1">
    <mxGraphModel>
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```


### 3.2 Deliverable: the timing table
In `docs/03_baseline_timings.md`, fill this table for **all 30** queries:

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Artist page: artist 33's 10 most-streamed tracks in the last 28 days | READ | | | | |
| R02: Album page: tracklist of album 1469 | READ | | | | |
| R03: Search: tracks whose title contains "love", most popular first | READ | | | | |
| R04: "Recently played": user 1038's last 50 streams | READ | | | | |
| R05: Playlist page: playlist 501 in order, with every artist on each track | READ | | | | |
| R06: "Liked Songs": user 1038's liked tracks, newest first | READ | | | | |
| R07: Royalties: streams of 30 seconds or more ("royalty-eligible") per artist in June 2026, top 20 | READ | | | | |
| R08: Spotify for Artists: skip rate of each of artist 33's tracks | READ | | | | |
| R09: Wrapped 2025: user 1038's top 5 artists by minutes listened | READ | | | | |
| R10: Platform analytics: daily streams per platform in June 2026 | READ | | | | |
| R11: "Release Radar": 2026 releases by artists user 1038 follows | READ | | | | |
| R12: Compliance: explicit tracks streamed by users who were under 18 at the time | READ | | | | |
| R13: Curation team: public playlists that have never been played | READ | | | | |
| R14: Collaborative playlists: number of different people who added tracks | READ | | | | |
| R15: "Fans also like": artists most followed by the followers of artist 33 | READ | | | | |
| R16: Artist profiles: distinct listeners of every artist in the last 28 days ("monthly listeners") | READ | | | | |
| R17: Growth: free users with 4+ streams in June 2026 (Premium upsell list) | READ | | | | |
| R18: Platform analytics: share of offline listening per platform | READ | | | | |
| R19: Verified artists report: total streams and the latest stream of every verified artist | READ | | | | |
| R20: Listening patterns: streams per hour of the day per country | READ | | | | |
| R21: Rights management: look up a recording by its ISRC code | READ | | | | |
| R22: Playlist hygiene: playlists that contain the same track more than once | READ | | | | |
| R23: Support console: all streams, newest first, page 8,001 (25 per page) | READ | | | | |
| R24: Label report: average track length and explicit share per album type | READ | | | | |
| R25: Discovery: tracks released in the last 30 days, ranked by streams | READ | | | | |
| W01: Player: log a stream of track 1389 by user 1038 | WRITE | | | | |
| W02: Heart button: user 1038 likes track 1389 | WRITE | | | | |
| W03: "Add to playlist": append track 1389 to the end of playlist 501 | WRITE | | | | |
| W04: Nightly job: recompute every artist's monthly listeners (last 28 days) | WRITE | | | | |
| W05: Takedown: the label withdrew the whole album of track 1389, so remove its tracks from every playlist | WRITE | | | | |
| **Total (sum of all 30)** | | | | | |

Below the table, add for each query the **scan type** from the plan (Seq Scan, Index Scan, …) and one line on **why** it is slow or fast.

---

## Phase 4: Optimize the queries

Make the queries faster. **The results must stay the same** (same rows; order matters only where the query has an `ORDER BY`).

### 4.1 Techniques you may use
| Technique | Example |
|-----------|---------|
| B-tree index (single / composite) | the right column **order** matters: equality columns first, then range/sort |
| Partial index | index only the rows a query needs (e.g. a rare status) |
| Covering index | `INCLUDE (...)` so the table is never visited (Index Only Scan) |
| Expression index | index the exact expression used in `WHERE` |
| GIN index | for `ILIKE '%text%'` (extension `pg_trgm`), arrays or full-text search |
| BRIN index | for huge tables stored in time order |
| Query rewrite | sargable date ranges instead of functions on columns; `NOT EXISTS` instead of `NOT IN`; joins instead of correlated subqueries; keyset instead of `OFFSET` pagination; `UNION ALL` instead of `OR` across columns |
| VACUUM / ANALYZE | fresh statistics and visibility maps |
| Summary table / materialized view | for heavy reports that don't need live data (state how it's refreshed) |

**Not allowed:** changing the data, deleting rows, changing PostgreSQL server settings to hide the problem (e.g. huge `work_mem`, `enable_seqscan = off`), or caching results outside the database.

### 4.2 How to work
1. Put every index in `sql/05_indexes.sql`, each with a comment: **which queries it serves and why this type and column order**.
2. Put rewritten queries in `sql/06_optimized_queries.sql`. Copy `queries/workload_30.sql` and change **only** the queries you rewrite, keeping the `-- @R01` markers.
3. **Prove the results are unchanged** for every rewritten query (compare row counts, plus a checksum or an `EXCEPT` query). Put the proof in your report.
4. Benchmark again with the same method:
```bash
./benchmarks/run_benchmark.sh <your_database> optimized 5 sql/06_optimized_queries.sql
```
> 🔎 **Read the results, not just the timings.** At least one of the 30 original queries returns a **wrong answer** because of a subtle SQL rule about NULLs. Find it, explain it, and fix it. This is worth marks.

### 4.3 Deliverable: the optimization table
In `docs/04_optimization_report.md`:

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|-------|------------:|---------------------------|----------------------|-----------:|------------:|:------------:|
| R04 | | e.g. Seq Scan on 250k streams | e.g. index on `streams(user_id, started_at DESC)` | | e.g. 99% (160×) | ✅ |
| … all 30 … | | | | | | |
| **Total** | | | | | | |

Improvement % = (before − after) / before × 100

Also include:
- **Before/after `EXPLAIN` plans** for your 5 biggest improvements
- **Write overhead:** which write queries got **slower** because of your indexes, by how much, and whether that's acceptable
- **Index storage:** the size of each index you created (`pg_relation_size`) compared with its table
- **Queries you could not speed up**, and why (an honest "this query must read most of the table" earns marks)

---

## Phase 5: Scalability report (large dataset round)

Your optimizations worked on 250,000 streams. Next year the business expects **20× the volume**.

By **Thu 19 Nov 2026**, faculty will release **`large_data.zip`**: the same 10 CSV files with about **20× the rows** (≈ 5,000,000 streams, ≈ 2,400,000 playlist tracks, ≈ 1,356,000 tracks, ≈ 600,000 users). Until then, work on the design part of the report.

### 5.1 What to do with the large dataset
1. Create a new database. Run **your** `01_schema.sql`, load `large_data/` with your load script (change the folder name only), then run **your** `05_indexes.sql` and `ANALYZE`.
2. Run your **optimized** queries (`sql/06_optimized_queries.sql`). **Do not run the original 30 on the large data.** Some of them could run for a very long time.
   - R23 pages with `OFFSET`; if you replaced it with keyset pagination, explain how the "last seen" value is chosen for the large data.
3. Record the times and compare with your Phase 4 results on the seed data.

| Query | Optimized on seed (ms) | Optimized on large (ms) | Growth (large ÷ seed) | Meets target? | If not, what you changed |
|-------|------------------------:|------------------------:|----------------------:|:-------------:|--------------------------|
| R01 | | | | | |
| … all 30 … | | | | | |

### 5.2 Performance targets on the large dataset
| Query group | Queries | Target (average of 3 runs) |
|-------------|---------|----------------:|
| Real-time / listener-facing | R02, R04, R05, R06, R11, R21, W01, W02, W03 | **under 5 ms** |
| Interactive artist tools and search | R01, R03, R08, R09, R13, R15, R22, R25, W05 | **under 250 ms** |
| Reports and analytics | R07, R10, R12, R14, R16, R17, R18, R19, R20, R23, R24 | **under 5,000 ms** |
| Batch jobs | W04 | **under 3,000 ms** |

If a query misses its target, **find out why from the plan and fix it.** A query that was fast on the seed data can become slow on large data for reasons that only appear at scale. Show the before/after plans for every fix.

### 5.3 Deliverable: `docs/05_scalability_report.md`
1. **Results table** (above), with every target met or explained.
2. **Growth analysis.** Group your queries by how their time grew when the data grew 20×:
   - *stayed about the same* (why? e.g. index lookups grow with log n)
   - *grew about 20×* (why? e.g. they read a fixed *share* of the table)
   - *grew more than 20×* (why, and what you did about it)
3. **What broke at scale** and how you fixed it (plans before/after).
4. **Storage:** total database size, table vs index size, on seed and large data.
5. **Architecture for 100×:** explain with numbers from your own measurements:
   - **Partitioning:** which table, by which column (RANGE / LIST / HASH), and why. Write the DDL for `streams`, show partition pruning with `EXPLAIN`, and note the primary-key rule for partitioned tables.
   - **Sharding:** Would you shard streams by user, by track/artist, or by time? Think about Recently Played (one user) vs royalty and artist reports (one artist, all users). Which queries become cross-shard, and how would you handle them?
   - **Read replicas and caching:** which of the 30 queries you would send to a replica or cache, and which must hit the primary.
   - **Maintenance:** VACUUM/autovacuum settings for `streams`, archiving old data, refreshing summary tables.
6. **Conclusion:** is your database ready for next year? What are the remaining risks?

---

## Repository structure (submit exactly this)

```
spotify-dbms-<team-no>/
├── README.md                          # team table, how to run, headline numbers
├── team.json                          # group lead, members, enrollment numbers
├── docs/
│   ├── 01_problem_understanding.md
│   ├── 02_schema_design.md
│   ├── 03_baseline_timings.md
│   ├── 04_optimization_report.md
│   └── 05_scalability_report.md
├── diagrams/
│   └── er_diagram.png
├── sql/
│   ├── 01_schema.sql
│   ├── 02_load_data.sql
│   ├── 05_indexes.sql
│   ├── 06_optimized_queries.sql
│   └── 08_partitioning.sql
├── queries/
│   └── workload_30.sql                # given; do not edit
└── benchmarks/
    ├── run_benchmark.sh               # given
    └── results/
        ├── baseline/                  # Phase 3: summary.csv + raw plans
        ├── optimized/                 # Phase 4
        └── large/                     # Phase 5
```

`team.json`:
```json
{
  "team_number": "",
  "group_lead": { "name": "", "enrollment_no": "", "github": "" },
  "members": [
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" },
    { "name": "", "enrollment_no": "", "github": "" }
  ],
  "postgres_version": "",
  "laptop_used_for_benchmarks": ""
}
```

**Do not commit the CSV files** (`seed_data/`, `large_data/`); add them to `.gitignore`. They are too large and we already have them.

---

## Timeline

| Due | Work | Checkpoint |
|-----|------|------------|
| Tue 3 Nov 2026 | Clone this repo into your team's DE repo, add members, commit `team.json` | **CP0** Setup |
| Mon 16 Nov 2026 | Phase 1 + Phase 2 (schema, load, ER, data dictionary) | **CP1** Schema loads all seed data with no errors |
| Tue 17 Nov 2026 | Phase 3 (baseline, 3 runs, average) + start Phase 4 | **CP2** Baseline table for all 30 queries committed |
| Thu 19 Nov 2026 | Phase 4 (indexes, rewrites, wrong-result query) | **CP3** Optimization table committed |
| Mon 23 Nov 2026 | Phase 5 on the large dataset + final report | **CP4 Final submission:** last commit on the default branch |
| Wed 25 – Thu 26 Nov 2026 | Individual analysis, in class time | **CP5** Individual analysis |

Full list of files per checkpoint, including the AP repo: [`CHECKPOINTS.md`](CHECKPOINTS.md).

---

## Evaluation (40 marks)

These 40 marks are the DE part of the project: **Query Execution (10)** and **Code Optimization (30)**.
The AP project (20) and your Individual analysis (40) make up the rest of the 100.

| Phase | Criteria | Marks |
|-------|----------|------:|
| | **Query Execution** | **10** |
| 1 | Problems understood, stakeholders and query groups correctly identified | 2 |
| 2 | Correct data types (1), keys and foreign keys with justified delete rules (1), ≥12 meaningful CHECK / NOT NULL / UNIQUE constraints (1), ER diagram + normal-form analysis (1), data loads cleanly + integrity checks (1) | 5 |
| 3 | All 30 queries measured with the required method: 3 runs, average (1), raw plans committed (1), scan type and reason for each query (1) | 3 |
| | **Code Optimization** | **30** |
| 4 | Speed-up achieved with appropriate techniques (6), every index justified (3), results proven unchanged (2), wrong-result query found and explained (2), write overhead and index storage reported (3) | 16 |
| 5 | Large-dataset results with all targets met or explained (4), growth analysis (3), scale-only problems found and fixed (3), partitioning DDL + sharding/replica design backed by your numbers (4) | 14 |
| | **Total** | **40** |

**Integrity rules**
- Every number in your reports must match the raw plan files in `benchmarks/results/`. Copied or invented timings make the whole phase score 0.
- Every member must have commits; the commit history is checked.
- You may use AI tools to learn, but you must be able to explain every index and rewrite in your individual analysis.

---

## Appendix: the 30 queries

These are identical to `queries/workload_30.sql`. Use the file, not copy-paste from this page.

**R01: Artist page: artist 33's 10 most-streamed tracks in the last 28 days**
```sql
SELECT t.track_id, t.title, count(*) AS streams
FROM streams s
JOIN track_artists ta ON ta.track_id = s.track_id
JOIN tracks t         ON t.track_id = s.track_id
WHERE ta.artist_id = 33
  AND s.started_at >= '2026-06-03'
GROUP BY t.track_id, t.title
ORDER BY streams DESC
LIMIT 10;
```

**R02: Album page: tracklist of album 1469**
```sql
SELECT disc_no, track_no, title, duration_ms, explicit
FROM tracks
WHERE album_id = 1469
ORDER BY disc_no, track_no;
```

**R03: Search: tracks whose title contains "love", most popular first**
```sql
SELECT track_id, title, popularity
FROM tracks
WHERE title ILIKE '%love%'
ORDER BY popularity DESC
LIMIT 20;
```

**R04: "Recently played": user 1038's last 50 streams**
```sql
SELECT s.started_at, t.title, s.ms_played, s.platform
FROM streams s
JOIN tracks t ON t.track_id = s.track_id
WHERE s.user_id = 1038
ORDER BY s.started_at DESC
LIMIT 50;
```

**R05: Playlist page: playlist 501 in order, with every artist on each track**
```sql
SELECT pt.position, t.title,
       string_agg(ar.artist_name, ', ' ORDER BY ta.role DESC, ar.artist_name) AS artists
FROM playlist_tracks pt
JOIN tracks t         ON t.track_id = pt.track_id
JOIN track_artists ta ON ta.track_id = t.track_id
JOIN artists ar       ON ar.artist_id = ta.artist_id
WHERE pt.playlist_id = 501
GROUP BY pt.position, t.title
ORDER BY pt.position;
```

**R06: "Liked Songs": user 1038's liked tracks, newest first**
```sql
SELECT l.liked_at, t.track_id, t.title
FROM liked_tracks l
JOIN tracks t ON t.track_id = l.track_id
WHERE l.user_id = 1038
ORDER BY l.liked_at DESC;
```

**R07: Royalties: streams of 30 seconds or more ("royalty-eligible") per artist in June 2026, top 20**
```sql
SELECT ta.artist_id, count(*) AS eligible_streams
FROM streams s
JOIN track_artists ta ON ta.track_id = s.track_id
WHERE s.ms_played >= 30000
  AND s.started_at >= '2026-06-01' AND s.started_at < '2026-07-01'
GROUP BY ta.artist_id
ORDER BY eligible_streams DESC
LIMIT 20;
```

**R08: Spotify for Artists: skip rate of each of artist 33's tracks**
```sql
SELECT t.track_id, t.title, count(*) AS plays,
       round(100.0 * count(*) FILTER (WHERE s.skipped) / count(*), 1) AS skip_pct
FROM tracks t
JOIN track_artists ta ON ta.track_id = t.track_id AND ta.artist_id = 33
JOIN streams s        ON s.track_id = t.track_id
GROUP BY t.track_id, t.title
ORDER BY plays DESC;
```

**R09: Wrapped 2025: user 1038's top 5 artists by minutes listened**
```sql
SELECT ta.artist_id, ar.artist_name, round(sum(s.ms_played) / 60000.0, 1) AS minutes
FROM streams s
JOIN track_artists ta ON ta.track_id = s.track_id AND ta.role = 'PRIMARY'
JOIN artists ar       ON ar.artist_id = ta.artist_id
WHERE s.user_id = 1038
  AND EXTRACT(YEAR FROM s.started_at) = 2025
GROUP BY ta.artist_id, ar.artist_name
ORDER BY minutes DESC
LIMIT 5;
```

**R10: Platform analytics: daily streams per platform in June 2026**
```sql
SELECT started_at::date AS day, platform, count(*) AS streams
FROM streams
WHERE started_at::date BETWEEN '2026-06-01' AND '2026-06-30'
GROUP BY 1, 2
ORDER BY 1, 2;
```

**R11: "Release Radar": 2026 releases by artists user 1038 follows**
```sql
SELECT a.album_id, a.album_title, a.album_type, a.release_date, ar.artist_name
FROM artist_follows f
JOIN albums a   ON a.artist_id = f.artist_id
JOIN artists ar ON ar.artist_id = a.artist_id
WHERE f.user_id = 1038
  AND a.release_date >= '2026-01-01'
ORDER BY a.release_date DESC;
```

**R12: Compliance: explicit tracks streamed by users who were under 18 at the time**
```sql
SELECT s.stream_id, s.user_id, s.track_id, s.started_at
FROM streams s
JOIN users u  ON u.user_id = s.user_id
JOIN tracks t ON t.track_id = s.track_id
WHERE t.explicit
  AND age(s.started_at::date, u.birth_date) < interval '18 years'
ORDER BY s.started_at DESC
LIMIT 200;
```

**R13: Curation team: public playlists that have never been played**
```sql
SELECT p.playlist_id, p.name, p.owner_user_id
FROM playlists p
WHERE p.is_public
  AND p.playlist_id NOT IN (SELECT s.playlist_id FROM streams s);
```

**R14: Collaborative playlists: number of different people who added tracks**
```sql
SELECT p.playlist_id, p.name, count(DISTINCT pt.added_by_user_id) AS contributors, count(*) AS tracks
FROM playlists p
JOIN playlist_tracks pt ON pt.playlist_id = p.playlist_id
WHERE p.is_collaborative
GROUP BY p.playlist_id, p.name
ORDER BY contributors DESC, tracks DESC
LIMIT 50;
```

**R15: "Fans also like": artists most followed by the followers of artist 33**
```sql
SELECT f2.artist_id, ar.artist_name, count(*) AS shared_fans
FROM artist_follows f1
JOIN artist_follows f2 ON f2.user_id = f1.user_id AND f2.artist_id <> f1.artist_id
JOIN artists ar        ON ar.artist_id = f2.artist_id
WHERE f1.artist_id = 33
GROUP BY f2.artist_id, ar.artist_name
ORDER BY shared_fans DESC
LIMIT 10;
```

**R16: Artist profiles: distinct listeners of every artist in the last 28 days ("monthly listeners")**
```sql
SELECT ta.artist_id, count(DISTINCT s.user_id) AS listeners
FROM streams s
JOIN track_artists ta ON ta.track_id = s.track_id
WHERE s.started_at >= '2026-06-03'
GROUP BY ta.artist_id
ORDER BY listeners DESC;
```

**R17: Growth: free users with 4+ streams in June 2026 (Premium upsell list)**
```sql
SELECT s.user_id, count(*) AS streams
FROM streams s
JOIN users u ON u.user_id = s.user_id
WHERE u.subscription = 'FREE'
  AND s.started_at >= '2026-06-01'
GROUP BY s.user_id
HAVING count(*) >= 4
ORDER BY streams DESC;
```

**R18: Platform analytics: share of offline listening per platform**
```sql
SELECT platform, count(*) AS streams,
       round(100.0 * count(*) FILTER (WHERE offline) / count(*), 1) AS offline_pct
FROM streams
GROUP BY platform
ORDER BY streams DESC;
```

**R19: Verified artists report: total streams and the latest stream of every verified artist**
```sql
SELECT ar.artist_id, ar.artist_name,
       (SELECT count(*) FROM streams s JOIN track_artists ta ON ta.track_id = s.track_id
         WHERE ta.artist_id = ar.artist_id) AS total_streams,
       (SELECT max(s.started_at) FROM streams s JOIN track_artists ta ON ta.track_id = s.track_id
         WHERE ta.artist_id = ar.artist_id) AS last_streamed_at
FROM artists ar
WHERE ar.is_verified
ORDER BY total_streams DESC;
```

**R20: Listening patterns: streams per hour of the day per country**
```sql
SELECT u.country_code, EXTRACT(HOUR FROM s.started_at) AS hour, count(*) AS streams
FROM streams s
JOIN users u ON u.user_id = s.user_id
GROUP BY 1, 2
ORDER BY 1, 2;
```

**R21: Rights management: look up a recording by its ISRC code**
```sql
SELECT t.track_id, t.title, a.album_title, a.label
FROM tracks t
JOIN albums a ON a.album_id = t.album_id
WHERE t.isrc = 'INASA1301389';
```

**R22: Playlist hygiene: playlists that contain the same track more than once**
```sql
SELECT playlist_id, track_id, count(*) AS copies
FROM playlist_tracks
GROUP BY playlist_id, track_id
HAVING count(*) > 1
ORDER BY copies DESC, playlist_id;
```

**R23: Support console: all streams, newest first, page 8,001 (25 per page)**
```sql
SELECT stream_id, user_id, track_id, started_at, ms_played
FROM streams
ORDER BY started_at DESC
OFFSET 200000
LIMIT 25;
```

**R24: Label report: average track length and explicit share per album type**
```sql
SELECT a.album_type, count(*) AS tracks,
       round(avg(t.duration_ms) / 1000.0, 0) AS avg_seconds,
       round(100.0 * count(*) FILTER (WHERE t.explicit) / count(*), 1) AS explicit_pct
FROM tracks t
JOIN albums a ON a.album_id = t.album_id
GROUP BY a.album_type
ORDER BY tracks DESC;
```

**R25: Discovery: tracks released in the last 30 days, ranked by streams**
```sql
SELECT t.track_id, t.title, a.release_date, count(s.stream_id) AS streams
FROM albums a
JOIN tracks t        ON t.album_id = a.album_id
LEFT JOIN streams s  ON s.track_id = t.track_id
WHERE a.release_date >= DATE '2026-06-30' - 30
GROUP BY t.track_id, t.title, a.release_date
ORDER BY streams DESC, a.release_date DESC
LIMIT 50;
```

**W01: Player: log a stream of track 1389 by user 1038**
```sql
INSERT INTO streams (stream_id, user_id, track_id, started_at, ms_played, platform, source_type, skipped)
VALUES (90000001, 1038, 1389, '2026-07-01 07:30:00+05:30', 185000, 'ANDROID', 'SEARCH', FALSE);
```

**W02: Heart button: user 1038 likes track 1389**
```sql
INSERT INTO liked_tracks (user_id, track_id, liked_at)
VALUES (1038, 1389, '2026-07-01 07:33:00+05:30')
ON CONFLICT (user_id, track_id) DO NOTHING;
```

**W03: "Add to playlist": append track 1389 to the end of playlist 501**
```sql
INSERT INTO playlist_tracks (playlist_id, position, track_id, added_by_user_id, added_at)
SELECT 501, max(position) + 1, 1389, (SELECT owner_user_id FROM playlists WHERE playlist_id = 501),
       '2026-07-01 07:35:00+05:30'
FROM playlist_tracks
WHERE playlist_id = 501;
```

**W04: Nightly job: recompute every artist's monthly listeners (last 28 days)**
```sql
UPDATE artists ar
SET monthly_listeners = coalesce(s.n, 0)
FROM (SELECT a.artist_id, count(DISTINCT st.user_id) AS n
      FROM artists a
      LEFT JOIN track_artists ta ON ta.artist_id = a.artist_id
      LEFT JOIN streams st ON st.track_id = ta.track_id AND st.started_at >= '2026-06-03'
      GROUP BY a.artist_id) s
WHERE s.artist_id = ar.artist_id;
```

**W05: Takedown: the label withdrew the whole album of track 1389, so remove its tracks from every playlist**
```sql
DELETE FROM playlist_tracks
WHERE track_id IN (SELECT track_id FROM tracks WHERE album_id = (SELECT album_id FROM tracks WHERE track_id = 1389));
```
