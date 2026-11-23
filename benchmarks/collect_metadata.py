#!/usr/bin/env python3
"""Save reproducible PostgreSQL environment, storage and integrity evidence."""
import argparse
import json
import platform
import subprocess
from pathlib import Path


def query(database, sql):
    result = subprocess.run(
        ["psql", "-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1",
         "-d", database, "-c", sql],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


def collect(database):
    tables = ["artists", "users", "albums", "playlists", "tracks",
              "track_artists", "playlist_tracks", "liked_tracks",
              "artist_follows", "streams"]
    counts = {}
    for table in tables:
        counts[table] = query(database,
            f"SELECT json_build_object('rows', count(*), "
            f"'checksum', bit_xor(hashtextextended(t::text, 0))::text) "
            f"FROM spotify.{table} t;")
    return {
        "environment": query(database, """
            SELECT json_build_object(
                'captured_at', now(), 'database', current_database(),
                'version', version(), 'timezone', current_setting('TimeZone'),
                'shared_buffers', current_setting('shared_buffers'),
                'work_mem', current_setting('work_mem'),
                'max_parallel_workers_per_gather',
                    current_setting('max_parallel_workers_per_gather'),
                'enable_partition_pruning', current_setting('enable_partition_pruning'),
                'database_bytes', pg_database_size(current_database()));
        """),
        "host": {"machine": platform.machine(), "platform": platform.platform()},
        "tables": counts,
        # Sum physical tables (relkind=r), not zero-sized partitioned parents.
        # Table bytes include TOAST and auxiliary forks; index bytes are separate.
        "relations": query(database, """
            SELECT coalesce(json_agg(row_to_json(r) ORDER BY r.name), '[]')
            FROM (
                SELECT c.relname AS name, c.relkind,
                       pg_table_size(c.oid) AS table_bytes,
                       pg_indexes_size(c.oid) AS index_bytes,
                       pg_total_relation_size(c.oid) AS total_bytes
                FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'spotify' AND c.relkind IN ('r', 'm')
            ) r;
        """),
        "indexes": query(database, """
            SELECT coalesce(json_agg(row_to_json(i) ORDER BY i.name), '[]')
            FROM (
                SELECT indexrelname AS name, relname AS table_name,
                       pg_relation_size(indexrelid) AS bytes
                FROM pg_stat_user_indexes WHERE schemaname = 'spotify'
            ) i;
        """),
        "integrity": query(database, """
            SELECT json_build_object(
                'streams_longer_than_track', (
                    SELECT count(*) FROM spotify.streams s
                    JOIN spotify.tracks t USING (track_id)
                    WHERE s.ms_played > t.duration_ms),
                'tracks_without_exactly_one_primary_artist', (
                    SELECT count(*) FROM (
                        SELECT t.track_id FROM spotify.tracks t
                        LEFT JOIN spotify.track_artists ta USING (track_id)
                        GROUP BY t.track_id
                        HAVING count(*) FILTER (WHERE ta.role = 'PRIMARY') <> 1
                    ) invalid),
                'streams_before_album_release', (
                    SELECT count(*) FROM spotify.streams s
                    JOIN spotify.tracks t USING (track_id)
                    JOIN spotify.albums a USING (album_id)
                    WHERE s.started_at::date < a.release_date),
                'stream_min', (SELECT min(started_at) FROM spotify.streams),
                'stream_max', (SELECT max(started_at) FROM spotify.streams));
        """),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(collect(args.database), indent=2) + "\n")
    print(f"Saved metadata to {args.output}")
