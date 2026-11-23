-- Run after 08_partitioning.sql and 09_scalability_tuning.sql.
-- Validate the only CP4 query rewrite against its live aggregate snapshot.
\set ON_ERROR_STOP on
SET search_path TO spotify;
BEGIN ISOLATION LEVEL REPEATABLE READ;

CREATE TEMP TABLE live_duplicates AS
SELECT playlist_id, track_id, count(*) AS copies
FROM playlist_tracks
GROUP BY playlist_id, track_id
HAVING count(*) > 1;

SELECT 'live_R22' AS check_name, count(*) AS rows FROM live_duplicates
UNION ALL
SELECT 'materialized_R22', count(*) FROM playlist_duplicates
UNION ALL
SELECT 'live_only', count(*) FROM (
    SELECT * FROM live_duplicates EXCEPT ALL SELECT * FROM playlist_duplicates
) d
UNION ALL
SELECT 'materialized_only', count(*) FROM (
    SELECT * FROM playlist_duplicates EXCEPT ALL SELECT * FROM live_duplicates
) d;

DO $$
BEGIN
    IF EXISTS (
        (SELECT * FROM live_duplicates EXCEPT ALL SELECT * FROM playlist_duplicates)
        UNION ALL
        (SELECT * FROM playlist_duplicates EXCEPT ALL SELECT * FROM live_duplicates)
    ) THEN
        RAISE EXCEPTION 'R22 materialized report is stale or incorrect';
    END IF;
END $$;

-- The stream migration itself checked exact rows with bidirectional EXCEPT ALL.
-- Inspect the resulting partitioned PK, FKs and CHECK constraints here.
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid = 'spotify.streams'::regclass
ORDER BY conname;

SELECT count(*) AS stream_rows, count(DISTINCT stream_id) AS distinct_stream_ids
FROM streams;

ROLLBACK;
