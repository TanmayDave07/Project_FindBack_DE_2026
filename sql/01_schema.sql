-- Spotify Music Streaming Database
-- Phase 2: schema creation
-- Run this file with psql against an empty PostgreSQL database.
-- Only PK, FK, UNIQUE, NOT NULL and CHECK constraints are created here.
-- No performance/tuning indexes are created in this phase.

CREATE SCHEMA IF NOT EXISTS spotify;
SET search_path TO spotify;

-- ---------------------------------------------------------------------------
-- 1. Artists
-- ---------------------------------------------------------------------------
CREATE TABLE artists (
    artist_id          INTEGER         NOT NULL,
    artist_name        VARCHAR(100)   NOT NULL,
    country_code       CHAR(2)        NOT NULL,
    primary_genre      VARCHAR(30)    NOT NULL,
    is_verified        BOOLEAN        NOT NULL,
    monthly_listeners  INTEGER        NOT NULL,

    created_at         TIMESTAMPTZ    NOT NULL,

    CONSTRAINT pk_artists PRIMARY KEY (artist_id),
    CONSTRAINT chk_artists_country_code
        CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_artists_monthly_listeners
        CHECK (monthly_listeners >= 0)
);

-- ---------------------------------------------------------------------------
-- 2. Users
-- ---------------------------------------------------------------------------
CREATE TABLE users (
    user_id       INTEGER         NOT NULL,
    email         VARCHAR(254)    NOT NULL,
    display_name  VARCHAR(100)    NOT NULL,
    country_code  CHAR(2)         NOT NULL,
    birth_date    DATE            NOT NULL,
    subscription  VARCHAR(20)     NOT NULL,
    created_at    TIMESTAMPTZ     NOT NULL,

    CONSTRAINT pk_users PRIMARY KEY (user_id),
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT chk_users_country_code
        CHECK (country_code ~ '^[A-Z]{2}$'),
    CONSTRAINT chk_users_subscription
        CHECK (subscription IN ('FREE', 'PREMIUM', 'DUO', 'FAMILY', 'STUDENT'))
);

-- ---------------------------------------------------------------------------
-- 3. Albums
-- ---------------------------------------------------------------------------
CREATE TABLE albums (
    album_id     INTEGER         NOT NULL,
    artist_id    INTEGER         NOT NULL,
    album_title  VARCHAR(150)    NOT NULL,
    album_type   VARCHAR(20)     NOT NULL,
    release_date DATE            NOT NULL,
    label        VARCHAR(100)    NOT NULL,
    upc          CHAR(12)        NOT NULL,

    CONSTRAINT pk_albums PRIMARY KEY (album_id),
    CONSTRAINT uq_albums_upc UNIQUE (upc),
    CONSTRAINT fk_albums_artist
        FOREIGN KEY (artist_id)
        REFERENCES artists (artist_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_albums_type
        CHECK (album_type IN ('ALBUM', 'EP', 'SINGLE', 'COMPILATION')),
    CONSTRAINT chk_albums_upc
        CHECK (upc ~ '^[0-9]{12}$')
);

-- ---------------------------------------------------------------------------
-- 4. Playlists
-- ---------------------------------------------------------------------------
CREATE TABLE playlists (
    playlist_id        INTEGER         NOT NULL,
    owner_user_id      INTEGER         NOT NULL,
    name               VARCHAR(150)    NOT NULL,
    is_public          BOOLEAN         NOT NULL,
    is_collaborative   BOOLEAN         NOT NULL,
    created_at         TIMESTAMPTZ     NOT NULL,

    CONSTRAINT pk_playlists PRIMARY KEY (playlist_id),
    CONSTRAINT fk_playlists_owner
        FOREIGN KEY (owner_user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_playlists_visibility
        CHECK (NOT (is_public AND is_collaborative))
);

-- ---------------------------------------------------------------------------
-- 5. Tracks
-- ---------------------------------------------------------------------------
CREATE TABLE tracks (
    track_id     INTEGER         NOT NULL,
    album_id     INTEGER         NOT NULL,
    disc_no      SMALLINT        NOT NULL,
    track_no     SMALLINT        NOT NULL,
    title        VARCHAR(200)    NOT NULL,
    duration_ms  INTEGER         NOT NULL,
    explicit     BOOLEAN         NOT NULL,
    isrc         CHAR(12)        NOT NULL,
    popularity   SMALLINT        NOT NULL,

    CONSTRAINT pk_tracks PRIMARY KEY (track_id),
    CONSTRAINT uq_tracks_album_disc_track
        UNIQUE (album_id, disc_no, track_no),
    CONSTRAINT uq_tracks_isrc UNIQUE (isrc),
    CONSTRAINT fk_tracks_album
        FOREIGN KEY (album_id)
        REFERENCES albums (album_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_tracks_disc_no
        CHECK (disc_no >= 1),
    CONSTRAINT chk_tracks_track_no
        CHECK (track_no >= 1),
    CONSTRAINT chk_tracks_duration
        CHECK (duration_ms > 0),
    CONSTRAINT chk_tracks_isrc
        CHECK (isrc ~ '^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$'),
    CONSTRAINT chk_tracks_popularity
        CHECK (popularity BETWEEN 0 AND 100)
);

-- ---------------------------------------------------------------------------
-- 6. Track artists (many-to-many: tracks <-> artists)
-- ---------------------------------------------------------------------------
CREATE TABLE track_artists (
    track_id   INTEGER       NOT NULL,
    artist_id  INTEGER       NOT NULL,
    role       VARCHAR(10)   NOT NULL,

    CONSTRAINT pk_track_artists PRIMARY KEY (track_id, artist_id),
    CONSTRAINT fk_track_artists_track
        FOREIGN KEY (track_id)
        REFERENCES tracks (track_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_track_artists_artist
        FOREIGN KEY (artist_id)
        REFERENCES artists (artist_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_track_artists_role
        CHECK (role IN ('PRIMARY', 'FEATURED'))
);

-- ---------------------------------------------------------------------------
-- 7. Playlist tracks (ordered many-to-many: playlists <-> tracks)
-- A track may occur more than once in the same playlist at different positions.
-- ---------------------------------------------------------------------------
CREATE TABLE playlist_tracks (
    playlist_id      INTEGER         NOT NULL,
    position         INTEGER         NOT NULL,
    track_id         INTEGER         NOT NULL,
    added_by_user_id INTEGER         NOT NULL,
    added_at         TIMESTAMPTZ     NOT NULL,

    CONSTRAINT pk_playlist_tracks PRIMARY KEY (playlist_id, position),
    CONSTRAINT fk_playlist_tracks_playlist
        FOREIGN KEY (playlist_id)
        REFERENCES playlists (playlist_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_playlist_tracks_track
        FOREIGN KEY (track_id)
        REFERENCES tracks (track_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_playlist_tracks_added_by
        FOREIGN KEY (added_by_user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_playlist_tracks_position
        CHECK (position >= 1)
);

-- ---------------------------------------------------------------------------
-- 8. Liked tracks (many-to-many: users <-> tracks)
-- ---------------------------------------------------------------------------
CREATE TABLE liked_tracks (
    user_id   INTEGER       NOT NULL,
    track_id  INTEGER       NOT NULL,
    liked_at  TIMESTAMPTZ   NOT NULL,

    CONSTRAINT pk_liked_tracks PRIMARY KEY (user_id, track_id),
    CONSTRAINT fk_liked_tracks_user
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_liked_tracks_track
        FOREIGN KEY (track_id)
        REFERENCES tracks (track_id)
        ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------------
-- 9. Artist follows (many-to-many: users <-> artists)
-- ---------------------------------------------------------------------------
CREATE TABLE artist_follows (
    user_id     INTEGER       NOT NULL,
    artist_id   INTEGER       NOT NULL,
    followed_at TIMESTAMPTZ   NOT NULL,

    CONSTRAINT pk_artist_follows PRIMARY KEY (user_id, artist_id),
    CONSTRAINT fk_artist_follows_user
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_artist_follows_artist
        FOREIGN KEY (artist_id)
        REFERENCES artists (artist_id)
        ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------------
-- 10. Streams
-- playlist_id is NULL for non-PLAYLIST sources and populated for PLAYLIST.
-- RESTRICT protects stream history from accidental parent deletion.
-- ---------------------------------------------------------------------------
CREATE TABLE streams (
    stream_id   INTEGER         NOT NULL,
    user_id     INTEGER         NOT NULL,
    track_id    INTEGER         NOT NULL,
    started_at  TIMESTAMPTZ     NOT NULL,
    ms_played   INTEGER         NOT NULL,
    platform    VARCHAR(20)     NOT NULL,
    source_type VARCHAR(20)     NOT NULL,
    playlist_id INTEGER,
    skipped     BOOLEAN         NOT NULL,
    offline     BOOLEAN         NOT NULL,

    CONSTRAINT pk_streams PRIMARY KEY (stream_id),
    CONSTRAINT fk_streams_user
        FOREIGN KEY (user_id)
        REFERENCES users (user_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_streams_track
        FOREIGN KEY (track_id)
        REFERENCES tracks (track_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_streams_playlist
        FOREIGN KEY (playlist_id)
        REFERENCES playlists (playlist_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_streams_ms_played
        CHECK (ms_played >= 0),
    CONSTRAINT chk_streams_platform
        CHECK (platform IN ('ANDROID', 'CAR', 'DESKTOP', 'IOS', 'SPEAKER', 'WEB')),
    CONSTRAINT chk_streams_source_type
        CHECK (source_type IN ('ALBUM', 'ARTIST', 'PLAYLIST', 'RADIO', 'SEARCH')),
    CONSTRAINT chk_streams_playlist_source
        CHECK (
            (source_type = 'PLAYLIST' AND playlist_id IS NOT NULL)
            OR
            (source_type <> 'PLAYLIST' AND playlist_id IS NULL)
        ),
    CONSTRAINT chk_streams_skipped_threshold
        CHECK (skipped = (ms_played < 30000))
);

-- End of Phase 2 schema.
-- PostgreSQL automatically creates indexes for PRIMARY KEY and UNIQUE
-- constraints. No additional indexes are created by this file.
