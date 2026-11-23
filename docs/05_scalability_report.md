# CP4 scalability report — Spotify / FindBack, team T0068

**Measured:** 23 November 2026, Asia/Kolkata. **Author:** Tanmay Dave.

The final configuration meets all **30/30 average latency targets** on the faculty's large dataset, including **5,000,000 streams**. It uses monthly stream partitions, a track-first index for playlist takedowns, and an in-database materialized duplicate-playlist report. The duplicate report is exact at refresh time and can lag committed playlist changes between refreshes.

## 1. Data, environment and measurement method

The CSVs were imported into a new database, `spotify_cp4_large`, without altering or deleting input rows. `sql/07_load_large_data.sql` is the existing transactional seed loader with only the input folder changed to `large_data/` and its comments updated. All original constraints accepted the large export. The CSVs remain ignored by Git; their actual row counts, byte lengths and SHA-256 hashes are in [dataset.json](../benchmarks/results/large/evidence/dataset.json).

| Table | Loaded large rows |
|---|---:|
| albums | 240,000 |
| artist_follows | 1,399,801 |
| artists | 60,000 |
| liked_tracks | 1,171,457 |
| playlist_tracks | 2,400,008 |
| playlists | 200,000 |
| streams | 5,000,000 |
| track_artists | 1,554,720 |
| tracks | 1,360,381 |
| users | 600,000 |

Streams, users, artists and albums grew exactly 20×. The other tables are close to 20×; for example tracks grew from 67,808 to 1,360,381. Stream timestamps span 1 January 2025 through 30 June 2026 in +05:30.

The host is a MacBook Pro with Apple M4, 16 GiB RAM, macOS 27.0.1, and PostgreSQL 18.6 (Homebrew). This matches the laptop and PostgreSQL version recorded in `team.json`. Measured server settings stayed at `shared_buffers=128MB`, `work_mem=4MB`, two parallel workers per gather, `TimeZone=Asia/Kolkata`, and partition pruning enabled. No server settings or planner switches were changed to obtain the results.

The supplied benchmark helper ran `EXPLAIN (ANALYZE, BUFFERS)` three times per query, in query-id order, using separate psql sessions. The reported latency is PostgreSQL's **Execution Time**, excluding planning, client/network latency, and rendering results in an application. Writes ran inside `BEGIN … ROLLBACK`. Validation and metadata scans preceded the final round, so it was not a cold-cache test. There was no separate timing warm-up or cache flush; the three runs include normal cache variation. No data loads, metadata collection or refresh measurements ran concurrently with the timed workload.

Two complete large-data rounds were retained:

- [large_before](../benchmarks/results/large_before/summary.csv): the CP3 optimized workload and seven CP3 indexes from base commit `ff3b498`, after import and `ANALYZE`, before the CP4 changes.
- [large](../benchmarks/results/large/summary.csv): the final optimized workload after `VACUUM (ANALYZE)`, the partition migration and the two scale fixes. Every query has a raw file with all three plans.

These are comparisons of the whole CP4 configuration, including maintenance and cache effects, rather than a controlled test of partitioning alone. The seed reference is the **existing CP3** [optimized summary](../benchmarks/results/optimized/summary.csv), not newly invented or rerun seed timings. Across-day system load and cache state can affect the growth ratios.

## 2. Results and targets

Targets are strict: average <5 ms for listener operations, <250 ms for interactive artist/search/curation tools, <5,000 ms for reports, and <3,000 ms for W04. Query links open the final three raw runs.

| Query | CP3 seed avg (ms) | Final large avg (ms) | Large / seed | Target (ms) | Met? | CP4 change / observation |
|---|---:|---:|---:|---:|:---:|---|
| [R01](../benchmarks/results/large/R01.txt) | 1.892 | 2.110 | 1.12× | <250 | Yes | Monthly pruning |
| [R02](../benchmarks/results/large/R02.txt) | 0.027 | 0.135 | 5.00× | <5 | Yes | Existing query retained |
| [R03](../benchmarks/results/large/R03.txt) | 23.446 | 167.765 | 7.16× | <250 | Yes | Existing query retained |
| [R04](../benchmarks/results/large/R04.txt) | 0.050 | 3.130 | 62.60× | <5 | Yes | Existing query retained |
| [R05](../benchmarks/results/large/R05.txt) | 0.164 | 0.996 | 6.07× | <5 | Yes | Existing query retained |
| [R06](../benchmarks/results/large/R06.txt) | 0.054 | 0.415 | 7.69× | <5 | Yes | Existing query retained |
| [R07](../benchmarks/results/large/R07.txt) | 8.430 | 727.497 | 86.30× | <5,000 | Yes | Monthly pruning |
| [R08](../benchmarks/results/large/R08.txt) | 0.941 | 15.364 | 16.33× | <250 | Yes | Existing query retained |
| [R09](../benchmarks/results/large/R09.txt) | 0.089 | 0.862 | 9.69× | <250 | Yes | Existing query retained |
| [R10](../benchmarks/results/large/R10.txt) | 10.909 | 298.978 | 27.41× | <5,000 | Yes | Existing query retained |
| [R11](../benchmarks/results/large/R11.txt) | 0.085 | 0.834 | 9.81× | <5 | Yes | Existing query retained |
| [R12](../benchmarks/results/large/R12.txt) | 7.931 | 106.188 | 13.39× | <5,000 | Yes | Existing query retained |
| [R13](../benchmarks/results/large/R13.txt) | 2.300 | 194.138 | 84.41× | <250 | Yes | Existing query retained |
| [R14](../benchmarks/results/large/R14.txt) | 8.109 | 190.908 | 23.54× | <5,000 | Yes | Existing query retained |
| [R15](../benchmarks/results/large/R15.txt) | 1.877 | 35.480 | 18.90× | <250 | Yes | Existing query retained |
| [R16](../benchmarks/results/large/R16.txt) | 9.816 | 978.890 | 99.72× | <5,000 | Yes | Monthly pruning |
| [R17](../benchmarks/results/large/R17.txt) | 3.725 | 119.983 | 32.21× | <5,000 | Yes | Monthly pruning |
| [R18](../benchmarks/results/large/R18.txt) | 15.163 | 458.546 | 30.24× | <5,000 | Yes | Existing query retained |
| [R19](../benchmarks/results/large/R19.txt) | 30.610 | 1250.373 | 40.85× | <5,000 | Yes | Existing query retained |
| [R20](../benchmarks/results/large/R20.txt) | 141.980 | 3904.403 | 27.50× | <5,000 | Yes | Existing query retained |
| [R21](../benchmarks/results/large/R21.txt) | 0.041 | 0.201 | 4.90× | <5 | Yes | Existing query retained |
| [R22](../benchmarks/results/large/R22.txt) | 22.755 | 4.624 | 0.20× | <250 | Yes | Materialized duplicate report; refresh after committed changes |
| [R23](../benchmarks/results/large/R23.txt) | 10.989 | 40.531 | 3.69× | <5,000 | Yes | Existing query retained |
| [R24](../benchmarks/results/large/R24.txt) | 11.478 | 176.125 | 15.34× | <5,000 | Yes | Existing query retained |
| [R25](../benchmarks/results/large/R25.txt) | 1.525 | 215.373 | 141.23× | <250 | Yes | Existing query retained |
| [W01](../benchmarks/results/large/W01.txt) | 0.582 | 1.616 | 2.78× | <5 | Yes | Existing query retained |
| [W02](../benchmarks/results/large/W02.txt) | 0.559 | 1.485 | 2.66× | <5 | Yes | Existing query retained |
| [W03](../benchmarks/results/large/W03.txt) | 0.510 | 1.924 | 3.77× | <5 | Yes | Existing query retained |
| [W04](../benchmarks/results/large/W04.txt) | 30.637 | 1929.810 | 62.99× | <3,000 | Yes | Monthly pruning |
| [W05](../benchmarks/results/large/W05.txt) | 6.522 | 0.370 | 0.06× | <250 | Yes | Added track-first playlist index |

The sum of the 30 average execution times is **353.196 ms** on the CP3 seed, **10,225.281 ms** for large-before, and **10,829.054 ms** for final-large. Final-large is **5.90% slower in total** than large-before, even though both missed targets were fixed. The sum is a sequential-workload comparison, not a throughput, concurrency or user-response-time measurement.

R20 dominates the final total at 3,904.403 ms. R25 (215.373 ms against 250 ms) and R13 (194.138 ms against 250 ms) have limited interactive headroom. All target decisions use the average of exactly three runs; no tail-latency or concurrent-load guarantee is implied.

## 3. What broke at scale and how it was fixed

### R22: duplicate detection repeatedly aggregated the full playlist table

The initial average was **742.677 ms**, over the 250 ms target. Its third plan processed **2,400,008 index entries**, fetched **2,211,922 heap tuples**, removed **2,328,008 nonduplicate groups**, and returned **36,000 duplicate groups**. A single diagnostic after VACUUM reduced heap fetches to 109 but still took **567.381 ms**: maintaining visibility maps helped, but the full aggregation remained expensive.

`sql/09_scalability_tuning.sql` materializes the exact duplicate groups in `spotify.playlist_duplicates`. A unique `(playlist_id, track_id)` index supports concurrent refresh. An index on `(copies DESC, playlist_id) INCLUDE (track_id)` supports the original report ordering without rescanning the 2.4 million entries. Only R22 was rewritten for CP4; its final average is **4.624 ms**, a **160.6×** improvement over large-before.

Third-run plan excerpts (full plans are retained):

```text
Before: GroupAggregate over Index Only Scan on playlist_tracks
        actual input rows=2400008; Heap Fetches=2211922
        Execution Time: 720.978 ms
After:  Index Only Scan using idx_playlist_duplicates_order
        actual rows=36000; Heap Fetches=0
        Execution Time: 5.032 ms
```

[Before plan](../benchmarks/results/large_before/R22.txt) · [After VACUUM diagnostic](../benchmarks/results/large/evidence/R22_after_vacuum.txt) · [Final plan](../benchmarks/results/large/R22.txt).

**Correctness and freshness:** a repeatable-read comparison of the live aggregate and materialized report returned 36,000 rows each, zero live-only rows and zero materialized-only rows, using `EXCEPT ALL` in both directions. The benchmark's playlist writes roll back, so the report stays exact for this workload. In an application, refresh after committed playlist edits/takedowns, or schedule refresh every five minutes if the curation team accepts that lag. The refresh policy is an architectural recommendation, not an installed scheduler. If R22 must reflect every committed edit immediately, implement transactional delta-maintained counts or refresh before serving the report; this snapshot design alone cannot promise immediate freshness.

Three actual concurrent-refresh measurements were **609.036, 572.875, 591.567 ms**, averaging **591.159 ms**. This separate batch cost is not included in the 4.624 ms read latency. The refresh still scans the underlying data and must be budgeted at larger scale. [Refresh evidence](../benchmarks/results/large/evidence/materialized_refresh.txt).

### W05: the existing playlist-first index could not seek by track

The initial average was **318.081 ms**, over the 250 ms target. W05 finds an album's tracks and removes them from every playlist. The existing `(playlist_id, track_id)` index could not efficiently answer the track-only lookup, so the plan scanned all **2,400,008 playlist entries**.

The CP4 addition to `sql/05_indexes.sql` creates `idx_playlist_tracks_track ON playlist_tracks(track_id)`. The SQL DELETE is unchanged. The final plan seeks by each of the album's 13 tracks and deletes the same 29 matching entries, inside the benchmark's rolled-back transaction. Its final average is **0.370 ms**, a **859.7×** improvement.

```text
Before: Hash Join over Seq Scan on playlist_tracks
        scanned rows=2400008; matching rows=29
After:  Nested Loop + Index Scan using idx_playlist_tracks_track
        Index Cond: track_id = tracks.track_id; matching rows=29
```

[Before plan](../benchmarks/results/large_before/W05.txt) · [Final plan](../benchmarks/results/large/W05.txt).

### Partitioning: useful pruning, with measurable join and planning costs

Partitioning did not improve every query. R01's average decreased from **9.762 to 2.110 ms**, but R07 increased from **154.542 to 727.497 ms**, R16 from **206.752 to 978.890 ms**, and R25 from **59.373 to 215.373 ms**. The final R07 plan prunes to June yet uses nested-loop probes into `track_artists` (594,728 shared buffer hits in run 3). R25 has no stream-time predicate and performs track probes across the monthly partitions. R04 probes multiple local user indexes through `Merge Append`, rising from 0.357 to 3.130 ms.

These queries still meet their targets. Keep the original and final plans as evidence of the tradeoff; a smaller scanned stream range does not ensure a better join strategy. At higher volume, use aggregate tables for artist reports and revisit the partition/index strategy for all-history user and track lookups. There is no claim that partitioning alone reduced the total workload time.

## 4. Growth analysis

Growth ratios below compare the CP3 seed averages with the final configuration, so they include changed plans and the R22 rewrite, not just row-count growth.

- **Stayed close or became faster:** R01 is 1.12× because recent-stream pruning narrows the work for one artist. R22 is 0.20× because it reads a small materialized report; W05 is 0.06× because its former table scan became indexed lookups. The latter two improvements come from changed designs, not constant-time full-table processing.
- **Sublinear growth, roughly 2–10×:** R02, R05, R06, R09, R11, R21, R23 and W01–W03. Equality lookups still retrieve small result sets, and the workload's fixed user/album/playlist IDs do not request 20× as many returned rows. R23 still skips a fixed 200,000 rows; its offset did not grow with database size. Very small seed times also amplify ratios.
- **Roughly proportional, about 10–30×:** R03, R08, R10, R12, R14, R15, R20 and R24. Searches, joins and aggregates process a similar fraction of the now-larger tables. R20 reaches 27.50× and its third run spills sorting to disk: approximately 29 MB per worker and 43,044 temporary blocks read. R10's `started_at::date` predicate is retained and scans partitions because it is not a direct timestamp range.
- **More than 30×:** R04 (62.60×), R07 (86.30×), R13 (84.41×), R16 (99.72×), R17 (32.21×), R18 (30.24×), R19 (40.85×), R25 (141.23×), and W04 (62.99×). Partition fan-out explains part of R04/R13/R25's growth. R07/R16 use many indexed join probes. All-history scans cannot prune, and larger joins/`COUNT(DISTINCT)` operations can spill at the unchanged 4 MB `work_mem`. W04 touches 60,000 artists and its final third plan reads 11,549 temporary blocks. These exceed the 20× row-growth expectation but meet their current targets; higher-scale remedies are discussed below.

## 5. Storage and write overhead

Storage was read from `pg_database_size`, `pg_table_size`, `pg_indexes_size` and `pg_relation_size`. The seed storage database was recreated from the same CSV archive with the **original seven CP3 tuning indexes** from commit `ff3b498`. Its timings were not substituted for the historic seed benchmark. The final large database includes the new index, all partition-local indexes and the materialized report. The unpartitioned source table was removed after the exact migration check, so it is not counted twice.

Table bytes include TOAST and auxiliary forks. Physical leaf tables are summed; zero-sized partition parents are excluded. Database size also includes catalogs and other overhead, so it need not equal table plus index bytes. Sizes below use **MiB = 1,048,576 bytes**. Large sizes were captured after their respective benchmark rounds, before the separate refresh timing round; seed sizes were captured after loading, indexing and VACUUM.

| Configuration | Whole database (MiB) | Table / MV bytes (MiB) | Index bytes (MiB) | Tables + indexes (MiB) |
|---|---:|---:|---:|---:|
| Seed, CP3 indexes | 106.79 | 44.99 | 53.80 | 98.80 |
| Large, unpartitioned CP3 | 1977.21 | 893.26 | 1075.95 | 1969.20 |
| Large, final CP4 | 2132.77 | 895.03 | 1228.97 | 2124.00 |

[Seed metadata](../benchmarks/results/large/evidence/seed_metadata.json) · [Unpartitioned metadata](../benchmarks/results/large/evidence/unpartitioned_metadata.json) · [Final metadata](../benchmarks/results/large/evidence/after_benchmark_metadata.json). Those files contain every physical table and individual index size in bytes.

Stream storage alone:

| Configuration | Stream table bytes (MiB) | Stream index bytes (MiB) |
|---|---:|---:|
| Seed | 20.16 | 30.92 |
| Large before | 399.26 | 616.63 |
| Large partitioned | 399.48 | 725.36 |

The final stream indexes are larger than the unpartitioned ones: the composite primary key is wider, and local track/playlist indexes are less able to deduplicate keys across months. Index maintenance and partition metadata are real costs.

| Tuning index / family | Final large size (MiB) | Purpose |
|---|---:|---|
| idx_albums_artist_release | 5.16 | Release Radar |
| idx_playlist_duplicates_key | 0.79 | CP4 concurrent refresh |
| idx_playlist_duplicates_order | 1.09 | CP4 duplicate report ordering |
| idx_playlist_tracks_playlist_track | 72.12 | Playlist grouping / contributors |
| idx_playlist_tracks_track | 42.41 | CP4 takedown lookup |
| idx_track_artists_artist_track | 33.32 | Artist-to-track lookup |
| Stream primary key | 150.59 | Composite constraint index; sum across all partitions |
| Playlist | 41.75 | Played-playlist existence; sum across all partitions |
| Time + track | 193.52 | Date ranges and pagination; sum across all partitions |
| Track | 102.84 | Track stream lookup; sum across all partitions |
| User + time | 236.66 | User history; sum across all partitions |

W01 went from 1.711 to 1.616 ms, W02 from 1.486 to 1.485 ms, W03 from 2.215 to 1.924 ms, W04 from 1,983.495 to 1,929.810 ms, and W05 from 318.081 to 0.370 ms, comparing the two large rounds. None got slower in these measured averages. This does not prove index maintenance is free: the new 42.41 MiB playlist track index must be updated on committed inserts/deletes, partitioned stream indexes must be maintained, and the duplicate view's refresh cost is measured separately. Cache variation and VACUUM also affect these comparisons. Write latency excludes COMMIT durability/network time because the benchmark rolls transactions back.

## 6. Architecture for 100× the seed volume

100× means approximately **25 million streams**, **3 million users**, and **6.8 million tracks**—five times the measured large round. A simple linear estimate from the final footprint is approximately **10.4 GiB** for the whole database and **5.5 GiB** for streams plus its indexes. These are capacity estimates, not measurements; retention, index compression, bloat and changing distributions can alter them. Keep additional space for WAL, backups, temporary sorts and offline migration copies.

### Partitioning and primary keys

The executed [08_partitioning.sql](../sql/08_partitioning.sql) uses `PARTITION BY RANGE (started_at)` on `streams`. It creates monthly Asia/Kolkata boundaries for January 2025 through July 2026, plus a default partition for out-of-range arrivals. June has **274,725 rows**, only **5.49%** of the five-million-row stream table. The migration copies rows, checks `EXCEPT ALL` in both directions, and only then swaps the table names and removes the source, within one transaction and an exclusive lock.

```sql
CREATE TABLE spotify.streams_partitioned
    (LIKE spotify.streams INCLUDING DEFAULTS INCLUDING CONSTRAINTS)
    PARTITION BY RANGE (started_at);
ALTER TABLE spotify.streams_partitioned
    ADD PRIMARY KEY (stream_id, started_at);
-- FKs and the four local tuning-index families are recreated in 08.
CREATE TABLE spotify.streams_2026_06
    PARTITION OF spotify.streams_partitioned
    FOR VALUES FROM ('2026-06-01 00:00:00+05:30')
               TO ('2026-07-01 00:00:00+05:30');
```

The actual June-range pruning demonstration took **22.391 ms**. Its plan names only `Parallel Seq Scan on streams_2026_06`; other months and the default partition are absent. R07 likewise scans only June. R01/R16/R17/W04 retain the June predicate plus empty July/default branches where applicable. R10's cast and all-history reports do not receive this pruning benefit. [Executed DDL and pruning output](../benchmarks/results/large/evidence/partitioning.txt).

PostgreSQL requires the partition key in a partitioned unique/primary constraint. Consequently `(stream_id, started_at)` replaces `(stream_id)`. The export still has exactly 5,000,000 distinct IDs and all incoming data was preserved, but the composite PK permits the same stream_id at different timestamps. Use a global ID allocator/sequence for production writers; an allocator alone is an application policy, not database-enforced uniqueness of manually supplied IDs. If cross-time ID uniqueness must be enforced in the database, add a globally keyed registry with transactional writes and benchmark its cost. Future foreign keys to streams would need the timestamp too, or a registry design. The current schema has no incoming stream foreign keys.

Create future monthly partitions in advance. Monitor the default partition; move any rows that overlap a new month before attaching that month. Monthly boundaries should be explicit offsets to avoid timezone mistakes. Archive immutable months by detach/export/drop according to the retention policy, and test restore before deleting the only database copy. The exclusive-lock migration is suitable for this submission's isolated database; a live service needs a planned copy/catch-up/cutover migration.

### Sharding

Prefer **hash sharding by user_id** if stream ingestion and Recently Played become the dominant workloads. R04/R09 and W01 then route to one user shard. Use time partitions inside each shard for retention and date-range analytics. A directory or deterministic hash maps a user to its shard.

Artist/royalty queries R01/R07/R08/R16/R19/R25 and W04 become cross-shard because listeners of an artist are spread across user shards. Compute shard-local stream/royalty counts and listening durations, then combine them into reporting tables. Distinct listeners require exact deduplication/sets or a clearly labelled approximation; do not sum per-shard distinct counts blindly when a user can move shards. R18/R20 need cross-shard totals; R23 needs a merge of shard-ordered streams and is particularly costly with its deep OFFSET.

Track/artist sharding simplifies royalty lookup but makes one user's history cross-shard; multi-artist tracks also complicate ownership and fan-out. Time sharding helps date reports and archiving but makes all-history user lookup span time shards and concentrates writes on the newest shard. Choose from observed workload priorities rather than assuming one key makes all 30 queries local.

### Read replicas and caching

Send tolerant analytics R07/R10/R14–R20/R22/R24/R25 to replicas or reporting stores, with an explicit freshness budget. R22's snapshot can be served from a replica after refresh and replication catch-up. Cache album/artist/playlist metadata for R02/R05/R11 and search results for R03 using versioned keys or invalidation on edits. Use a brief TTL or refresh event for artist statistics. Cache only in a proposed production deployment; these benchmark results use no external cache.

W01–W05 execute on the primary. R04/R06 after a just-completed stream/like and R05 after a playlist edit require primary or a replica that has reached the write's WAL position. Rights/takedown-sensitive R21 should use authoritative primary data when immediate consistency matters. A lagging replica cannot guarantee read-after-write behavior merely because its SELECT is fast.

### Maintenance, summaries and remaining query work

The final database measured R20 at **3.90 seconds** and W04 at **1.93 seconds**. Naive fivefold projections are **19.5 seconds** and **9.65 seconds**, already beyond their targets; therefore the current full-aggregation design is not demonstrated ready for 100×. Build incrementally maintained daily platform/offline counters for R10/R18, country/hour counters for R20, and artist/day royalty aggregates for R07. For monthly distinct-listener statistics, maintain exact artist/user/day membership or another structure supporting an exact rolling window; update and expire memberships as days enter/leave the window. Measure refresh/update overhead rather than shifting it out of the reported total without accounting for it.

R03 still scans titles with a leading-wildcard ILIKE; consider a GIN trigram index and measure both search latency and write/storage cost if its 167.765 ms average worsens. R25 has little headroom after partition fan-out; a per-track stream-count summary with transactional or budgeted refresh can avoid 20 local index probes per track. R23 retains OFFSET 200000; it is not a keyset rewrite. For a production cursor, use the last emitted `(started_at, stream_id)` with a matching descending composite index and explicit tie-breaking in the query. A cursor is chosen from the previously delivered page, not guessed from the large export. That would be a separately validated workload change.

Keep autovacuum enabled on active leaf partitions so append-only stream pages become all-visible and index-only scans avoid heap fetches. Monitor dead tuples, visibility maps, freeze age, WAL and last vacuum/analyze times. For a measured month of about 275,000 rows, a starting insert-vacuum trigger such as threshold 1,000 plus scale factor 0.02 is roughly 6,500 inserted rows; tune leaf settings from operational measurements. This is a proposed production setting, not a change applied for the benchmark. Analyze the partitioned parent after substantial data changes because parent statistics also guide joins. Vacuum/analyze artist and playlist tables after batch writes, and separate heavy refreshes from latency-sensitive workloads.

## 7. Validation and conclusion

- All ten loaded counts match the actual large CSVs. Integrity checks found **zero** streams longer than their tracks, **zero** tracks without exactly one PRIMARY artist, and **zero** streams before album release.
- The partition migration's duplicate-sensitive, bidirectional `EXCEPT ALL` comparison passed before the source was dropped. PK, FKs, NOT NULLs and CHECK definitions were inspected afterward; the partitioned PK caveat is documented above.
- The R22 snapshot matches the live aggregate exactly in both directions. W05's query text is unchanged and its before/after plans affect the same 29 entries.
- All ten table counts and 64-bit row-hash XOR checksums match before migration, before the final benchmark and after its rolled-back writes. Those checksums are a mutation sanity check, not a collision-free substitute for the migration's exact row comparison.
- Both large rounds contain exactly **30 queries × 3 runs**, and every reported mean, median, minimum and maximum was checked against the **180 actual execution-time lines**. See [benchmark validation](../benchmarks/results/large/evidence/benchmark_validation.json), [SQL validation](../benchmarks/results/large/evidence/validation.txt) and [rollback validation](../benchmarks/results/large/evidence/rollback_validation.json).

The database meets all specified targets for the measured 20× dataset on this single laptop, with R22 served as an explicit refreshable reporting snapshot. It is ready for the checkpoint's next-year workload under those measured conditions. Remaining risks are narrow latency margins for R13/R25, R20's disk spill, partition fan-out, global stream-ID policy, report freshness and untested concurrent load. The measurements do not establish 100× readiness; summaries, workload-specific routing and additional load tests are required before making that claim.

## Reproduce the final round

Place the faculty CSVs in ignored `large_data/`, install PostgreSQL 15+ and Python 3, and run from the repository root:

```bash
bash benchmarks/run_scalability.sh spotify_cp4_reproduction large_reproduction
```

This creates a new database (fails rather than dropping an existing one), loads all ten files, applies indexes, VACUUM, monthly partitions and the report view, validates results, runs each optimized query three times, and records metadata before/after the benchmark. It uses the normal libpq connection environment. A new result folder preserves the submitted measurements. Running the current `06_optimized_queries.sql` on any fresh database requires `09_scalability_tuning.sql` first because R22 now reads the materialized report. To refresh after actual playlist edits:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY spotify.playlist_duplicates;
```
