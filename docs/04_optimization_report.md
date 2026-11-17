# CP3 – SQL Optimization Report

## 1. Objective

The objective of CP3 was to improve the performance of the Spotify PostgreSQL
database using indexes and SQL query rewrites while preserving query results.

The original workload contains 25 READ queries (R01–R25) and 5 WRITE queries
(W01–W05).

## 2. Benchmark methodology

- Baseline: CP2 benchmark results.
- Optimized workload: `sql/06_optimized_queries.sql`.
- Index definitions: `sql/05_indexes.sql`.
- Optimized benchmark: 3 runs per query.
- Database: `spotify_db`.
- PostgreSQL port: 5433.
- Optimized results: `benchmarks/results/optimized/summary.csv`.

The averages below are in milliseconds.

## 3. Before vs after performance

| Query | Type | Before (ms) | After (ms) | Improvement |
|---|---|---:|---:|---:|
| R01 | READ | 20.030 | 1.892 | 90.6% |
| R02 | READ | 0.068 | 0.027 | 60.3% |
| R03 | READ | 55.236 | 23.446 | 57.6% |
| R04 | READ | 12.271 | 0.050 | 99.6% |
| R05 | READ | 0.359 | 0.164 | 54.3% |
| R06 | READ | 0.108 | 0.054 | 50.0% |
| R07 | READ | 40.386 | 8.430 | 79.1% |
| R08 | READ | 34.511 | 0.941 | 97.3% |
| R09 | READ | 12.765 | 0.089 | 99.3% |
| R10 | READ | 24.224 | 10.909 | 55.0% |
| R11 | READ | 1.801 | 0.085 | 95.3% |
| R12 | READ | 44.977 | 7.931 | 82.4% |
| R13 | READ | 76.111 | 2.300 | 97.0% |
| R14 | READ | 30.073 | 8.109 | 73.0% |
| R15 | READ | 4.821 | 1.877 | 61.1% |
| R16 | READ | 57.145 | 9.816 | 82.8% |
| R17 | READ | 26.213 | 3.725 | 85.8% |
| R18 | READ | 41.779 | 15.163 | 63.7% |
| R19 | READ | 25490.058 | 30.610 | 99.9% |
| R20 | READ | 336.897 | 141.980 | 57.9% |
| R21 | READ | 0.084 | 0.041 | 51.2% |
| R22 | READ | 66.468 | 22.755 | 65.8% |
| R23 | READ | 100.672 | 10.989 | 89.1% |
| R24 | READ | 28.164 | 11.478 | 59.2% |
| R25 | READ | 39.912 | 1.525 | 96.2% |
| W01 | WRITE | 1.058 | 0.582 | 45.0% |
| W02 | WRITE | 0.799 | 0.559 | 30.0% |
| W03 | WRITE | 0.641 | 0.510 | 20.4% |
| W04 | WRITE | 113.610 | 30.637 | 73.0% |
| W05 | WRITE | 16.535 | 6.522 | 60.6% |

Improvement is calculated as:

`((Before - After) / Before) * 100`

## 4. Indexes added

Seven performance indexes were created:

1. `idx_track_artists_artist_track`
   - Supports artist-based track lookups and joins.
   - Used by R01, R08, R16 and R19.

2. `idx_streams_user_started`
   - Supports user-specific stream history ordered by time.
   - Used by R04 and R09.

3. `idx_streams_started_track`
   - Supports date-based stream filtering and time ordering.
   - Used by several stream analytics queries.

4. `idx_streams_playlist`
   - Partial index containing only non-NULL playlist IDs.
   - Supports the NOT EXISTS check in R13.

5. `idx_playlist_tracks_playlist_track`
   - Supports playlist and track lookups.
   - Intended for playlist-related queries.

6. `idx_streams_track`
   - Supports finding streams for a particular track.
   - Helps R08 and R25.

7. `idx_albums_artist_release`
   - Supports album lookup by artist and release date.
   - Helps R11.

## 5. Why queries became faster

### R01 – Artist track streams
The indexes on `streams` and `track_artists` reduce the work needed to find
streams in the requested date range and match the artist's tracks.

### R03 – Track title search
The query still performs a sequential scan because the leading-wildcard
ILIKE search (`%love%`) is not supported by an ordinary B-tree index.
The measured improvement should not be attributed to a new index.

### R04 and R09 – User stream history and artist listening
The composite index on `(user_id, started_at)` allows PostgreSQL to find a
user's streams efficiently and use the time ordering.

### R07, R16 and R17 – Stream analytics
The date-based index helps PostgreSQL locate relevant stream records.
Some joins and grouping operations still require additional scans.

### R08 and R25 – Track stream analysis
The index on `streams(track_id)` makes matching streams to tracks faster.
The artist-track index also helps R08 find tracks for the selected artist.

### R11 – Followed artist albums
The album index on `(artist_id, release_date DESC)` helps locate albums
belonging to followed artists and supports release-date ordering.

### R13 – Public playlists without streams
The original NOT IN query could produce incorrect results when its subquery
contained NULL values. It was rewritten using NOT EXISTS.
The partial index on non-NULL `streams.playlist_id` helps the existence check.

### R19 – Artist stream statistics
The original query used two correlated subqueries for every verified artist.
The rewritten query calculates COUNT and MAX together in a grouped
aggregation and joins the result to artists. This avoids repeatedly
calculating the same stream statistics.

### R23 – Recent stream pagination
The started_at index supports ordering by stream time. However, OFFSET
still requires PostgreSQL to skip earlier rows, so deep pagination remains
more expensive than a query using a suitable keyset cursor.

### R14, R18, R20, R22 and R24 – Aggregation queries
These queries process large portions of their tables to calculate counts,
averages or grouped statistics. Sequential scans can be appropriate for
whole-table aggregations, so indexes do not necessarily eliminate them.

### WRITE queries
Indexes can improve the lookup work needed by UPDATE and DELETE operations,
but every additional index also has to be maintained when rows change.
This creates a write and storage overhead that should be considered.

## 6. Remaining performance bottlenecks

The optimized plans still show sequential scans for some queries:

- R03: title search using ILIKE with a leading wildcard.
- R10 and R18: stream aggregation.
- R14 and R22: playlist-track aggregation.
- R20: country and hour aggregation.
- R24: album-type aggregation.

These scans are not automatically problems. They may be appropriate when
a query needs to process a large percentage of a table.

## 7. Important validation still required

The benchmark summary records execution averages and scan-node descriptions.
It does not by itself prove that every rewritten query returns exactly the
same rows as the original.

Before final submission, validate rewritten query results using row counts
and EXCEPT comparisons (in both directions), with the R13 NULL-related
correction documented separately.

Also inspect the raw execution plans for the five largest improvements,
measure index storage using `pg_relation_size`, and document write overhead.

## 8. Conclusion

The optimized benchmark shows lower average execution times for all 30
queries compared with the supplied CP2 baseline.

The largest measured improvement is R19, which decreased from
25,490.058 ms to 30.610 ms after replacing repeated correlated subqueries
with one grouped aggregation.

Indexes improved several stream, artist, album and playlist lookups.
Some full-table aggregation and pattern-search queries still use sequential
scans and may need different optimization strategies.

The benchmark results are stored in:
`benchmarks/results/optimized/summary.csv`

## 9. Execution plan analysis

The optimized raw execution plans were inspected for R19, R09, R08, R13 and R04.
Each query has three recorded benchmark plans.

### R19 – Aggregation rewrite

The plan uses a Parallel Hash Join, Partial HashAggregate and Finalize
HashAggregate, followed by a Hash Right Join with verified artists.
The streams table is scanned in parallel and artist statistics are
calculated together. Execution time in the three plans was approximately
30.847 ms, 30.592 ms and 30.390 ms.

### R09 – User stream lookup

The plan uses Index Only Scan on `idx_streams_user_started` with
`user_id = 1038`, followed by track-artist and artist index lookups.
The year extraction remains a filter, not an index range condition.
Execution times were approximately 0.092 ms, 0.090 ms and 0.086 ms.

### R08 – Artist track stream analysis

The plan uses `idx_track_artists_artist_track` to locate tracks for
artist 33, primary-key lookups on tracks, and `idx_streams_track`
to retrieve matching streams. This avoids scanning the entire streams
table for the selected artist's tracks.
Execution times were approximately 0.978 ms, 1.009 ms and 0.836 ms.

### R13 – Public playlists without streams

The plan uses a Nested Loop Anti Join. Public playlists are scanned,
and `idx_streams_playlist` is used through Index Only Scan to check
whether a playlist has a matching stream.
Execution times were approximately 2.295 ms, 2.295 ms and 2.311 ms.

### R04 – User stream history

The plan uses Index Only Scan on `idx_streams_user_started` to find
the user's streams, followed by primary-key lookups on tracks.
Execution times were approximately 0.058 ms, 0.047 ms and 0.044 ms.

These plans confirm that the listed indexes and query rewrite are used
by PostgreSQL in the optimized workload.

## 10. Index storage analysis

Index sizes were measured using PostgreSQL's pg_relation_size()
function.

| Index | Storage |
|---|---:|
| idx_streams_user_started | 12 MB |
| idx_streams_started_track | 9912 kB |
| idx_playlist_tracks_playlist_track | 3712 kB |
| idx_streams_track | 3192 kB |
| idx_track_artists_artist_track | 1712 kB |
| idx_streams_playlist | 928 kB |
| idx_albums_artist_release | 280 kB |

The seven additional indexes occupy approximately 31.7 MB.
Indexes improve lookup performance but require additional disk storage
and maintenance during INSERT, UPDATE and DELETE operations.

## 11. Query result validation

### R19 – Equivalence test

The original correlated-subquery query and optimized aggregation query
were compared using EXCEPT in both directions.

| Check | Rows |
|---|---:|
| Original result | 334 |
| Optimized result | 334 |
| Original-only rows | 0 |
| Optimized-only rows | 0 |

Result: PASS. Both queries return exactly the same rows.

### R13 – NULL-related correctness fix

The original NOT IN query and optimized NOT EXISTS query were compared.

| Query | Rows |
|---|---:|
| Original NOT IN | 0 |
| Optimized NOT EXISTS | 1891 |

The streams subquery contains NULL playlist_id values. NOT IN can therefore
evaluate to UNKNOWN and incorrectly return no playlists.
NOT EXISTS correctly checks for a matching stream for each public playlist.

Result: Intentional correctness correction. The two queries are not
equivalent because the original query has a NULL-related bug.
