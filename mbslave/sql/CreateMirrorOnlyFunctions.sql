\set ON_ERROR_STOP 1

BEGIN;

CREATE OR REPLACE FUNCTION a_ins_release_mirror()
RETURNS trigger AS $$
BEGIN
    INSERT INTO artist_release_pending_update VALUES (NEW.id);
    INSERT INTO artist_release_group_pending_update VALUES (NEW.release_group);
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_upd_release_mirror()
RETURNS trigger AS $$
BEGIN
    IF (
        NEW.status IS DISTINCT FROM OLD.status OR
        NEW.release_group != OLD.release_group OR
        NEW.artist_credit != OLD.artist_credit
    ) THEN
        INSERT INTO artist_release_group_pending_update
        VALUES (NEW.release_group), (OLD.release_group);
    END IF;
    IF (
        NEW.barcode IS DISTINCT FROM OLD.barcode OR
        NEW.name != OLD.name OR
        NEW.artist_credit != OLD.artist_credit
    ) THEN
        INSERT INTO artist_release_pending_update VALUES (OLD.id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_del_release_mirror()
RETURNS trigger AS $$
BEGIN
    INSERT INTO artist_release_pending_update VALUES (OLD.id);
    INSERT INTO artist_release_group_pending_update VALUES (OLD.release_group);
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_ins_release_event_mirror()
RETURNS trigger AS $$
BEGIN
    PERFORM set_release_first_release_date(NEW.release);
    PERFORM set_releases_recordings_first_release_dates(ARRAY[NEW.release]);
    IF TG_TABLE_NAME = 'release_country' THEN
        INSERT INTO artist_release_pending_update VALUES (NEW.release);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_upd_release_event_mirror()
RETURNS trigger AS $$
BEGIN
    PERFORM set_release_first_release_date(OLD.release);
    PERFORM set_release_first_release_date(NEW.release);
    PERFORM set_releases_recordings_first_release_dates(ARRAY[NEW.release, OLD.release]);
    IF TG_TABLE_NAME = 'release_country' THEN
        IF NEW.country != OLD.country THEN
            INSERT INTO artist_release_pending_update VALUES (OLD.release);
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_del_release_event_mirror()
RETURNS trigger AS $$
BEGIN
    PERFORM set_release_first_release_date(OLD.release);
    PERFORM set_releases_recordings_first_release_dates(ARRAY[OLD.release]);
    IF TG_TABLE_NAME = 'release_country' THEN
        INSERT INTO artist_release_pending_update VALUES (OLD.release);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_ins_release_group_mirror()
RETURNS trigger AS $$
BEGIN
    INSERT INTO artist_release_group_pending_update VALUES (NEW.id);
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_upd_release_group_mirror()
RETURNS trigger AS $$
BEGIN
    IF (
        NEW.name != OLD.name OR
        NEW.artist_credit != OLD.artist_credit OR
        NEW.type IS DISTINCT FROM OLD.type
     ) THEN
        INSERT INTO artist_release_group_pending_update VALUES (OLD.id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_del_release_group_mirror()
RETURNS trigger AS $$
BEGIN
    INSERT INTO artist_release_group_pending_update VALUES (OLD.id);
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_upd_release_group_meta_mirror()
RETURNS trigger AS $$
BEGIN
    IF (
        (NEW.first_release_date_year IS DISTINCT FROM OLD.first_release_date_year) OR
        (NEW.first_release_date_month IS DISTINCT FROM OLD.first_release_date_month) OR
        (NEW.first_release_date_day IS DISTINCT FROM OLD.first_release_date_day)
    ) THEN
        INSERT INTO artist_release_group_pending_update VALUES (OLD.id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_ins_release_group_secondary_type_join_mirror()
RETURNS trigger AS $$
BEGIN
    INSERT INTO artist_release_group_pending_update VALUES (NEW.release_group);
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_del_release_group_secondary_type_join_mirror()
RETURNS trigger AS $$
BEGIN
    INSERT INTO artist_release_group_pending_update VALUES (OLD.release_group);
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_ins_release_label_mirror()
RETURNS trigger AS $$
BEGIN
    INSERT INTO artist_release_pending_update VALUES (NEW.release);
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_upd_release_label_mirror()
RETURNS trigger AS $$
BEGIN
    IF NEW.catalog_number IS DISTINCT FROM OLD.catalog_number THEN
        INSERT INTO artist_release_pending_update VALUES (OLD.release);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_del_release_label_mirror()
RETURNS trigger AS $$
BEGIN
    INSERT INTO artist_release_pending_update VALUES (OLD.release);
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_ins_track_mirror()
RETURNS trigger AS $$
BEGIN
    PERFORM set_recordings_first_release_dates(ARRAY[NEW.recording]);
    INSERT INTO artist_release_pending_update (
        SELECT release FROM medium
        WHERE id = NEW.medium
    );
    INSERT INTO artist_release_group_pending_update (
        SELECT release_group FROM release
        JOIN medium ON medium.release = release.id
        WHERE medium.id = NEW.medium
    );
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_upd_track_mirror()
RETURNS trigger AS $$
BEGIN
    IF NEW.artist_credit != OLD.artist_credit THEN
        INSERT INTO artist_release_pending_update (
            SELECT release FROM medium
            WHERE id = OLD.medium
        );
        INSERT INTO artist_release_group_pending_update (
            SELECT release_group FROM release
            JOIN medium ON medium.release = release.id
            WHERE medium.id = OLD.medium
        );
    END IF;
    IF OLD.recording <> NEW.recording THEN
        PERFORM set_recordings_first_release_dates(ARRAY[OLD.recording, NEW.recording]);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

CREATE OR REPLACE FUNCTION a_del_track_mirror()
RETURNS trigger AS $$
BEGIN
    PERFORM set_recordings_first_release_dates(ARRAY[OLD.recording]);
    INSERT INTO artist_release_pending_update (
        SELECT release FROM medium
        WHERE id = OLD.medium
    );
    INSERT INTO artist_release_group_pending_update (
        SELECT release_group FROM release
        JOIN medium ON medium.release = release.id
        WHERE medium.id = OLD.medium
    );
    RETURN NULL;
END;
$$ LANGUAGE 'plpgsql' SET search_path = musicbrainz, public;

COMMIT;
