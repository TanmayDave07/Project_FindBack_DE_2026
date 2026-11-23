-- CP4: migrate the loaded, indexed streams table to monthly RANGE partitions.
-- Run ONCE, from the repository root, after 01_schema, 07_load_large_data
-- and 05_indexes: psql -X -v ON_ERROR_STOP=1 -d spotify_cp4_large -f sql/08_partitioning.sql
-- This offline migration takes an exclusive lock and temporarily needs room
-- for a second copy of streams and its indexes. No server settings are changed.
-- PostgreSQL requires the partition key in a partitioned PRIMARY KEY:
-- (stream_id, started_at) replaces (stream_id). It does NOT enforce global
-- uniqueness of stream_id across different timestamps. Production writers
-- must allocate globally unique IDs; there are no incoming stream foreign keys.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL search_path TO spotify;
SET LOCAL TIME ZONE 'Asia/Kolkata';
LOCK TABLE spotify.streams IN ACCESS EXCLUSIVE MODE;

-- LIKE preserves all column types, NOT NULLs, defaults and CHECK constraints.
-- Foreign keys and indexes must be recreated explicitly.
CREATE TABLE spotify.streams_partitioned
    (LIKE spotify.streams INCLUDING DEFAULTS INCLUDING CONSTRAINTS)
    PARTITION BY RANGE (started_at);
ALTER TABLE spotify.streams_partitioned
    ADD CONSTRAINT pk_streams_partitioned PRIMARY KEY (stream_id, started_at),
    ADD CONSTRAINT fk_streams_partitioned_user FOREIGN KEY (user_id)
        REFERENCES spotify.users (user_id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_streams_partitioned_track FOREIGN KEY (track_id)
        REFERENCES spotify.tracks (track_id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_streams_partitioned_playlist FOREIGN KEY (playlist_id)
        REFERENCES spotify.playlists (playlist_id) ON DELETE RESTRICT;

-- Use local calendar months, matching the dataset's +05:30 timestamps.
-- Precreate one extra month for W01 and the next month's incoming events.
DO $$
DECLARE
    month_start timestamptz;
    stop_month timestamptz;
BEGIN
    SELECT date_trunc('month', min(started_at)),
           date_trunc('month', max(started_at)) + interval '2 months'
    INTO month_start, stop_month
    FROM spotify.streams;
    IF month_start IS NULL THEN
        RAISE EXCEPTION 'Load streams before running the partition migration';
    END IF;
    WHILE month_start < stop_month LOOP
        EXECUTE format(
            'CREATE TABLE spotify.%I PARTITION OF spotify.streams_partitioned '
            'FOR VALUES FROM (%L) TO (%L)',
            'streams_' || to_char(month_start, 'YYYY_MM'),
            month_start, month_start + interval '1 month');
        month_start := month_start + interval '1 month';
    END LOOP;
END $$;

-- Keep out-of-range arrivals writable; monitor this partition and create
-- future monthly partitions ahead of time (move overlapping default rows first).
CREATE TABLE spotify.streams_other
    PARTITION OF spotify.streams_partitioned DEFAULT;

INSERT INTO spotify.streams_partitioned SELECT * FROM spotify.streams;

-- The four CP3 stream indexes become local indexes on every partition.
-- No CREATE INDEX is needed on individual child tables.
CREATE INDEX idx_streams_partitioned_user_started
    ON spotify.streams_partitioned (user_id, started_at DESC)
    INCLUDE (track_id, ms_played, platform);
CREATE INDEX idx_streams_partitioned_started_track
    ON spotify.streams_partitioned (started_at DESC, track_id)
    INCLUDE (stream_id, user_id, ms_played);
CREATE INDEX idx_streams_partitioned_playlist
    ON spotify.streams_partitioned (playlist_id) WHERE playlist_id IS NOT NULL;
CREATE INDEX idx_streams_partitioned_track
    ON spotify.streams_partitioned (track_id);

-- Exact, duplicate-sensitive comparison in both directions, before removing
-- the source. Any lost, changed or additional row aborts the entire migration.
DO $$
BEGIN
    IF EXISTS (
        (SELECT * FROM spotify.streams
         EXCEPT ALL SELECT * FROM spotify.streams_partitioned)
        UNION ALL
        (SELECT * FROM spotify.streams_partitioned
         EXCEPT ALL SELECT * FROM spotify.streams)
    ) THEN
        RAISE EXCEPTION 'Partition migration changed stream rows';
    END IF;
    RAISE NOTICE 'PASS: streams preserved exactly (EXCEPT ALL in both directions)';
END $$;

-- No CASCADE: unexpected dependent objects stop the migration safely.
DROP TABLE spotify.streams;
ALTER TABLE spotify.streams_partitioned RENAME TO streams;
COMMIT;

-- Refresh parent/child statistics and visibility maps for index-only scans.
VACUUM (ANALYZE) spotify.streams;

-- Same date predicate as R07: only the June partition should be scanned.
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM spotify.streams
WHERE started_at >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND started_at < TIMESTAMPTZ '2026-07-01 00:00:00+05:30';

SELECT relid::regclass AS partition, isleaf
FROM pg_partition_tree('spotify.streams')
ORDER BY relid::regclass::text;
