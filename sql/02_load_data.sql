-- Spotify Music Streaming Database
-- Phase 2: load the 10 seed CSV files.
--
-- Run this file with psql from the repository root, after running
-- sql/01_schema.sql. The README expects the CSV files in seed_data/.
--
-- Example:
--   psql -d your_database -f sql/01_schema.sql
--   psql -d your_database -f sql/02_load_data.sql
--
-- ON_ERROR_STOP makes psql stop at the first failed command. The transaction
-- ensures that a failed import does not leave a partially loaded dataset.

\set ON_ERROR_STOP on

SET search_path TO spotify;

BEGIN;

-- Parent tables first, followed by tables that reference them.
\copy spotify.artists (artist_id, artist_name, country_code, primary_genre, is_verified, monthly_listeners, created_at) FROM 'seed_data/artists.csv' WITH (FORMAT csv, HEADER true)
\copy spotify.users (user_id, email, display_name, country_code, birth_date, subscription, created_at) FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true)
\copy spotify.albums (album_id, artist_id, album_title, album_type, release_date, label, upc) FROM 'seed_data/albums.csv' WITH (FORMAT csv, HEADER true)
\copy spotify.playlists (playlist_id, owner_user_id, name, is_public, is_collaborative, created_at) FROM 'seed_data/playlists.csv' WITH (FORMAT csv, HEADER true)
\copy spotify.tracks (track_id, album_id, disc_no, track_no, title, duration_ms, explicit, isrc, popularity) FROM 'seed_data/tracks.csv' WITH (FORMAT csv, HEADER true)
\copy spotify.track_artists (track_id, artist_id, role) FROM 'seed_data/track_artists.csv' WITH (FORMAT csv, HEADER true)
\copy spotify.playlist_tracks (playlist_id, position, track_id, added_by_user_id, added_at) FROM 'seed_data/playlist_tracks.csv' WITH (FORMAT csv, HEADER true)
\copy spotify.liked_tracks (user_id, track_id, liked_at) FROM 'seed_data/liked_tracks.csv' WITH (FORMAT csv, HEADER true)
\copy spotify.artist_follows (user_id, artist_id, followed_at) FROM 'seed_data/artist_follows.csv' WITH (FORMAT csv, HEADER true)
\copy spotify.streams (stream_id, user_id, track_id, started_at, ms_played, platform, source_type, playlist_id, skipped, offline) FROM 'seed_data/streams.csv' WITH (FORMAT csv, HEADER true)

COMMIT;

-- Refresh planner statistics after loading.
ANALYZE;

-- Verify the loaded row counts against the Phase 2 counts in README.md.
SELECT 'artists' AS table_name, COUNT(*) AS row_count FROM spotify.artists
UNION ALL
SELECT 'albums', COUNT(*) FROM spotify.albums
UNION ALL
SELECT 'tracks', COUNT(*) FROM spotify.tracks
UNION ALL
SELECT 'track_artists', COUNT(*) FROM spotify.track_artists
UNION ALL
SELECT 'users', COUNT(*) FROM spotify.users
UNION ALL
SELECT 'playlists', COUNT(*) FROM spotify.playlists
UNION ALL
SELECT 'playlist_tracks', COUNT(*) FROM spotify.playlist_tracks
UNION ALL
SELECT 'streams', COUNT(*) FROM spotify.streams
UNION ALL
SELECT 'liked_tracks', COUNT(*) FROM spotify.liked_tracks
UNION ALL
SELECT 'artist_follows', COUNT(*) FROM spotify.artist_follows
ORDER BY table_name;
