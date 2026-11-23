
-- ============================================================
-- CP3: Performance indexes for Spotify database
-- Existing primary-key and UNIQUE indexes are not recreated.
-- ============================================================

SET search_path TO spotify;

-- R01, R08, R16, R19:
-- Find tracks belonging to an artist efficiently.
-- artist_id first because these queries filter/group by artist.
CREATE INDEX idx_track_artists_artist_track
ON spotify.track_artists (artist_id, track_id);

-- R04, R09:
-- Recently played and user-specific stream history.
-- user_id equality first, followed by descending time.
CREATE INDEX idx_streams_user_started
ON spotify.streams (user_id, started_at DESC)
INCLUDE (track_id, ms_played, platform);

-- R01, R07, R10, R16, R17, R23, W04:
-- Supports date filtering, stream joins and newest-first pagination.
CREATE INDEX idx_streams_started_track
ON spotify.streams (started_at DESC, track_id)
INCLUDE (stream_id, user_id, ms_played);

-- R13:
-- Efficiently check whether a playlist has ever been played.
-- Only non-NULL playlist references are indexed.
CREATE INDEX idx_streams_playlist
ON spotify.streams (playlist_id)
WHERE playlist_id IS NOT NULL;

-- R14, R22:
-- Playlist contributor aggregation and duplicate-track detection.
CREATE INDEX idx_playlist_tracks_playlist_track
ON spotify.playlist_tracks (playlist_id, track_id)
INCLUDE (added_by_user_id);

-- R25:
-- Find streams for tracks efficiently during release discovery.
CREATE INDEX idx_streams_track
ON spotify.streams (track_id);

-- R11:
-- Find albums by artist and release date.
CREATE INDEX idx_albums_artist_release
ON spotify.albums (artist_id, release_date DESC);

-- CP4 W05: at 2.4 million playlist entries, an album takedown must not scan
-- every playlist. The existing (playlist_id, track_id) index cannot seek
-- by track_id alone; put track_id first for this DELETE's equality lookup.
CREATE INDEX idx_playlist_tracks_track
ON spotify.playlist_tracks (track_id);
