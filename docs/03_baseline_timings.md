# Phase 3: Baseline timings

**Team T0068** · Spotify music streaming database

Baseline = the schema from Phase 2 **with no tuning**: only the indexes PostgreSQL creates itself for PRIMARY KEY and UNIQUE constraints. No extra index, no query rewrite. This is the reference every Phase 4 improvement is measured against.

## How it was measured

| Item | Value |
|------|-------|
| Database | PostgreSQL 16.15, schema `spotify`, loaded from `seed_data/` (250,000 streams) |
| Method | `EXPLAIN (ANALYZE, BUFFERS)`, **3 runs** per query, `Execution Time` of each run recorded, average of the three reported |
| Command | `./benchmarks/run_benchmark.sh <db> baseline` |
| Writes | W01 to W05 run inside `BEGIN; ... ROLLBACK;` so the data does not change |
| State | Fresh rebuild with `sql/01_schema.sql` + `sql/02_load_data.sql` (which ends with `ANALYZE`). No manual VACUUM and no extra indexes, because those are Phase 4 techniques. |
| Server settings | Defaults (`shared_buffers` 128MB, `work_mem` 4MB), nothing tuned |
| Machine | 16 vCPU Intel Xeon @ 2.1 GHz, 8 GB RAM, Linux. The same machine must be used again for Phase 4 |
| Raw plans | `benchmarks/results/baseline/R01.txt` ... `W05.txt` (all 3 runs each) and `summary.csv` |

> Runs 1 to 3 are listed in the order they were executed. All data was already in memory (`shared hit`), so these are warm-cache timings.

## Timing table

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Artist page: artist 33's 10 most-streamed tracks in the last 28 days | READ | 18.027 | 20.755 | 21.309 | 20.030 |
| R02: Album page: tracklist of album 1469 | READ | 0.057 | 0.072 | 0.074 | 0.068 |
| R03: Search: tracks whose title contains "love", most popular first | READ | 56.271 | 56.369 | 53.068 | 55.236 |
| R04: "Recently played": user 1038's last 50 streams | READ | 12.435 | 12.302 | 12.075 | 12.271 |
| R05: Playlist page: playlist 501 in order, with every artist on each track | READ | 0.361 | 0.344 | 0.372 | 0.359 |
| R06: "Liked Songs": user 1038's liked tracks, newest first | READ | 0.103 | 0.128 | 0.093 | 0.108 |
| R07: Royalties: streams of 30 seconds or more ("royalty-eligible") per artist in June 2026, top 20 | READ | 44.571 | 40.466 | 36.121 | 40.386 |
| R08: Spotify for Artists: skip rate of each of artist 33's tracks | READ | 37.207 | 36.523 | 29.804 | 34.511 |
| R09: Wrapped 2025: user 1038's top 5 artists by minutes listened | READ | 12.986 | 12.779 | 12.529 | 12.765 |
| R10: Platform analytics: daily streams per platform in June 2026 | READ | 20.963 | 24.906 | 26.804 | 24.224 |
| R11: "Release Radar": 2026 releases by artists user 1038 follows | READ | 1.671 | 1.719 | 2.012 | 1.801 |
| R12: Compliance: explicit tracks streamed by users who were under 18 at the time | READ | 47.283 | 43.779 | 43.868 | 44.977 |
| R13: Curation team: public playlists that have never been played | READ | 71.542 | 83.130 | 73.660 | 76.111 |
| R14: Collaborative playlists: number of different people who added tracks | READ | 31.257 | 32.079 | 26.883 | 30.073 |
| R15: "Fans also like": artists most followed by the followers of artist 33 | READ | 5.327 | 4.552 | 4.585 | 4.821 |
| R16: Artist profiles: distinct listeners of every artist in the last 28 days ("monthly listeners") | READ | 46.874 | 77.655 | 46.906 | 57.145 |
| R17: Growth: free users with 4+ streams in June 2026 (Premium upsell list) | READ | 24.804 | 25.348 | 28.487 | 26.213 |
| R18: Platform analytics: share of offline listening per platform | READ | 44.172 | 38.504 | 42.660 | 41.779 |
| R19: Verified artists report: total streams and the latest stream of every verified artist | READ | 25,627.792 | 25,223.245 | 25,619.138 | 25,490.058 |
| R20: Listening patterns: streams per hour of the day per country | READ | 295.991 | 402.329 | 312.371 | 336.897 |
| R21: Rights management: look up a recording by its ISRC code | READ | 0.079 | 0.102 | 0.072 | 0.084 |
| R22: Playlist hygiene: playlists that contain the same track more than once | READ | 89.096 | 53.936 | 56.371 | 66.468 |
| R23: Support console: all streams, newest first, page 8,001 (25 per page) | READ | 97.550 | 108.441 | 96.025 | 100.672 |
| R24: Label report: average track length and explicit share per album type | READ | 29.453 | 26.574 | 28.464 | 28.164 |
| R25: Discovery: tracks released in the last 30 days, ranked by streams | READ | 42.412 | 39.337 | 37.987 | 39.912 |
| W01: Player: log a stream of track 1389 by user 1038 | WRITE | 1.431 | 0.885 | 0.859 | 1.058 |
| W02: Heart button: user 1038 likes track 1389 | WRITE | 0.797 | 0.784 | 0.816 | 0.799 |
| W03: "Add to playlist": append track 1389 to the end of playlist 501 | WRITE | 0.651 | 0.663 | 0.609 | 0.641 |
| W04: Nightly job: recompute every artist's monthly listeners (last 28 days) | WRITE | 106.034 | 112.192 | 122.604 | 113.610 |
| W05: Takedown: the label withdrew the whole album of track 1389, so remove its tracks from every playlist | WRITE | 16.450 | 16.011 | 17.143 | 16.535 |
| **Total (sum of all 30)** | | **26,783.647** | **26,495.909** | **26,753.769** | **26,677.776** |

R19 alone is **95.5%** of the total. Without R19 the other 29 queries add up to 1,187.718 ms.

## Slowest five (where Phase 4 should start)

| Rank | Query | Average (ms) | Main reason |
|---:|---|---:|---|
| 1 | R19 | 25,490.058 | correlated subqueries repeated for every verified artist |
| 2 | R20 | 336.897 | whole-table join and group of all streams |
| 3 | W04 | 113.610 | recomputes all artists' monthly listeners with a full scan |
| 4 | R23 | 100.672 | `OFFSET 200000` sorts and discards 200k rows |
| 5 | R13 | 76.111 | full scan of streams and a wrong `NOT IN` |

## Scan type and why each query is slow or fast

Scan nodes are taken from the plan of the last run (`summary.csv`, column `scan_nodes`).

| Query | Avg (ms) | Scan type(s) in the plan | Why it is slow or fast |
|---|---:|---|---|
| R01 | 20.030 | Seq Scan on streams <br> Seq Scan on track_artists <br> Index Scan using pk_tracks on tracks | No index on `streams(track_id)` or `started_at`, so all 250k streams are scanned and then joined to artist 33's tracks. Fast in absolute terms only because the table is small. |
| R02 | 0.068 | Index Scan using uq_tracks_album_disc_track on tracks | Served by the unique index `(album_id, disc_no, track_no)`: one album, already in the requested order, so no sort is needed. |
| R03 | 55.236 | Seq Scan on tracks | `ILIKE '%love%'` has a leading wildcard, so a B-tree cannot help. Every one of the 67,808 titles is read and then sorted by popularity. |
| R04 | 12.271 | Seq Scan on streams <br> Index Scan using pk_tracks on tracks | No index on `streams(user_id)`. The whole table is scanned to find one user's streams, then sorted by `started_at`. Gets worse as streams grow. |
| R05 | 0.359 | Index Scan using pk_playlist_tracks on playlist_tracks <br> Index Scan using pk_tracks on tracks <br> Index Scan using pk_track_artists on track_artists <br> Index Scan using pk_artists on artists | Everything is reached through primary keys (playlist, track, track_artists, artists). Playlist 501 is small, so it is already fast. |
| R06 | 0.108 | Index Scan using pk_liked_tracks on liked_tracks <br> Index Scan using pk_tracks on tracks | The primary key `(user_id, track_id)` finds one user's likes directly. Only a small sort by `liked_at` is left. |
| R07 | 40.386 | Seq Scan on streams <br> Seq Scan on track_artists | Seq Scan over all streams to apply the June 2026 and 30-second filters, then a join to `track_artists` and a grouped top 20. Reads a large share of the table. |
| R08 | 34.511 | Seq Scan on streams <br> Seq Scan on track_artists <br> Index Scan using pk_tracks on tracks | `streams` has no index on `track_id`, so all streams are scanned and hash-joined to artist 33's tracks. `track_artists` is also scanned because its PK starts with `track_id`, not `artist_id`. |
| R09 | 12.765 | Seq Scan on streams <br> Index Scan using pk_track_artists on track_artists <br> Index Scan using pk_artists on artists | No index on `streams(user_id)`. `EXTRACT(YEAR ...)` on the column also stops any date index from being used (not sargable). |
| R10 | 24.224 | Seq Scan on streams | `started_at::date` casts the column, so the filter is not sargable. All streams are scanned and the date is computed for each row. |
| R11 | 1.801 | Seq Scan on albums <br> Index Only Scan using pk_artist_follows on artist_follows <br> Index Scan using pk_artists on artists | `albums` has no index on `artist_id` or `release_date`, so albums are scanned. The follow lookup is a PK index scan. Small tables, so it is still about 1 ms. |
| R12 | 44.977 | Seq Scan on streams <br> Seq Scan on tracks <br> Index Scan using pk_users on users | Joins all 250k streams to users and tracks, and `age(...)` is computed for every row. The filter involves two tables, so no single index can cover it. |
| R13 | 76.111 | Seq Scan on playlists <br> Seq Scan on streams | **Returns a WRONG answer (0 rows).** `NOT IN (SELECT playlist_id FROM streams)` meets NULLs: 137,386 streams have `playlist_id IS NULL`, so `NOT IN` is never true. `NOT EXISTS` returns 1,891 rows. It is also slow because of the full scan of `streams`. |
| R14 | 30.073 | Seq Scan on playlist_tracks <br> Seq Scan on playlists | Seq Scans on `playlists` and `playlist_tracks`, then `count(DISTINCT)` per playlist with a sort. No index on `playlist_tracks(added_by_user_id)` or on `playlists(is_collaborative)`. |
| R15 | 4.821 | Seq Scan on artist_follows <br> Index Only Scan using pk_artist_follows on artist_follows <br> Index Scan using pk_artists on artists | Self-join of `artist_follows`. `artist_follows` has no index on `artist_id`, so followers of artist 33 are found by a Seq Scan. The second step uses the PK. |
| R16 | 57.145 | Seq Scan on streams <br> Seq Scan on track_artists | `count(DISTINCT user_id)` over all streams since 3 June, joined to `track_artists`. Scans `streams` and needs a sort or hash per artist. |
| R17 | 26.213 | Seq Scan on streams <br> Seq Scan on users | Scans all streams since 1 June and joins to users to check `subscription = 'FREE'`. No supporting index. |
| R18 | 41.779 | Seq Scan on streams | A report that needs every row of `streams`, so a Seq Scan is expected. An index would not help, only a summary table could. |
| R19 | 25,490.058 | Seq Scan on artists <br> Seq Scan on streams <br> Index Only Scan using pk_track_artists on track_artists | **Slowest query (about 25 s).** A correlated subquery runs twice per verified artist (334 artists). Each run joins all streams to `track_artists`, so the same join is repeated more than 600 times. It should become one `GROUP BY` join. |
| R20 | 336.897 | Seq Scan on streams <br> Seq Scan on users | Reads all streams, joins users, and extracts the hour for each row. It reads the whole table by design. The extra time comes from the hash join and sorting about 250k rows. |
| R21 | 0.084 | Index Scan using uq_tracks_isrc on tracks <br> Index Scan using pk_albums on albums | The unique index on `isrc` finds the one track directly, then one join to `albums` by PK. |
| R22 | 66.468 | Seq Scan on playlist_tracks | Seq Scan over all 120k `playlist_tracks` rows, grouped by `(playlist_id, track_id)`. The PK is `(playlist_id, position)`, so it cannot detect duplicate tracks. |
| R23 | 100.672 | Seq Scan on streams | `ORDER BY started_at DESC OFFSET 200000` has to sort the whole table and throw away 200,000 rows to return 25. Needs an index on `started_at` plus keyset pagination. |
| R24 | 28.164 | Seq Scan on tracks <br> Seq Scan on albums | Reads all tracks and joins albums to group by type. It is a whole-table report, so the scan is expected. |
| R25 | 39.912 | Seq Scan on streams <br> Seq Scan on albums <br> Index Scan using uq_tracks_album_disc_track on tracks | `LEFT JOIN streams` on `track_id` with no index scans all streams. `albums.release_date` has no index either. |
| W01 | 1.058 | (no scan) | A single-row INSERT. It only pays for the PK, 2 FK checks, and CHECK constraints. This is the baseline write cost before any extra indexes. |
| W02 | 0.799 | (no scan) | A single-row INSERT with `ON CONFLICT` on the PK `(user_id, track_id)`. Fast because the PK is the only index. |
| W03 | 0.641 | Index Scan using pk_playlists on playlists <br> Index Only Scan using pk_playlist_tracks on playlist_tracks | `max(position)` is read from the PK `(playlist_id, position)`, then one row is inserted. Fast. The `max()+1` pattern is not safe with concurrent writers, but that is a separate concern. |
| W04 | 113.610 | Index Scan using pk_artists on artists <br> Seq Scan on streams <br> Seq Scan on track_artists <br> Seq Scan on artists | An UPDATE of all 3,000 artists driven by a subquery with `count(DISTINCT ...)` over streams. It scans streams and `track_artists` and rewrites every artist row. |
| W05 | 16.535 | Index Scan using pk_tracks on tracks <br> Seq Scan on playlist_tracks <br> Index Scan using uq_tracks_album_disc_track on tracks | Deletes from `playlist_tracks` using a track-id subquery. There is no index on `playlist_tracks(track_id)`, so the whole table is scanned to find matching rows. |

## Observations

1. **Only primary-key and unique indexes exist**, so every query that filters `streams` by anything other than `stream_id` reads the full 250,000 rows. Of the 25 reads, 19 have a Seq Scan on a large table (15 of them on `streams`).
2. **R19 is an outlier** at about 25 seconds. This is the "several seconds" query the brief warns about. It is caused by the query shape (correlated subqueries), not by missing statistics.
3. **R13 returns a wrong result**, not just a slow one: 0 rows with `NOT IN`, 1,891 rows with `NOT EXISTS`. The cause is NULL values in `streams.playlist_id`. This is the NULL-rule bug the brief says to find, so it belongs in Phase 4.
4. **Non-sargable filters** (`started_at::date`, `EXTRACT(YEAR ...)`, `ILIKE '%...%'`, `age(...)`) in R03, R09, R10 and R12 mean an index alone will not fix them. They need a rewrite or a different index type (for example `pg_trgm` for R03).
5. **R18, R20 and R24 read most of a table by design.** Expect a limited gain from indexes here. A summary table or materialized view is the better tool.
6. **Writes are cheap today** (W01 to W03 about 1 ms) because the tables have almost no secondary indexes. Every index added in Phase 4 will slow them down a little, so this is the baseline for the write-overhead section.
7. **Timings are small because the data fits in memory.** Several queries are 20 to 60 ms at 250k streams. They scan the whole table, so they will grow about 20 times at 5 million streams. That is why the scan type matters more than the millisecond figure.

## Schema fix found while benchmarking

W01 failed on the first run with `null value in column "offline" violates not-null constraint`. The given INSERT does not send `offline`, but the Phase 2 schema had it `NOT NULL` with no default. The workload file must not be edited, so the schema was changed instead: `offline BOOLEAN NOT NULL DEFAULT FALSE` in `sql/01_schema.sql` (and noted in `docs/02_schema_design.md`). The data is unchanged, and the NOT NULL rule is kept.

## Reproduce

```bash
createdb findback
psql -d findback -f sql/01_schema.sql
psql -d findback -f sql/02_load_data.sql
./benchmarks/run_benchmark.sh findback baseline

```
