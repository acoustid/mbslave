import psycopg2
import pytest
import os


def test_db_connection():
    # Use the default credentials from Dockerfile.postgres
    conn = psycopg2.connect(
        host=os.environ.get("MBSLAVE_DB_HOST", "localhost"),
        port=int(os.environ.get("MBSLAVE_DB_PORT", "5432")),
        dbname=os.environ.get("MBSLAVE_DB_NAME", "musicbrainz"),
        user=os.environ.get("MBSLAVE_DB_USER", "musicbrainz"),
        password=os.environ.get("MBSLAVE_DB_PASSWORD", "musicbrainz")
    )
    cur = conn.cursor()
    cur.execute("SELECT 1")
    assert cur.fetchone()[0] == 1
    cur.close()
    conn.close()


def test_schemas_exist():
    conn = psycopg2.connect(
        host=os.environ.get("MBSLAVE_DB_HOST", "localhost"),
        port=int(os.environ.get("MBSLAVE_DB_PORT", "5432")),
        dbname=os.environ.get("MBSLAVE_DB_NAME", "musicbrainz"),
        user=os.environ.get("MBSLAVE_DB_USER", "musicbrainz"),
        password=os.environ.get("MBSLAVE_DB_PASSWORD", "musicbrainz")
    )
    cur = conn.cursor()
    schemas = ['musicbrainz', 'statistics', 'cover_art_archive', 'event_art_archive', 'wikidocs', 'documentation', 'dbmirror2']
    for schema in schemas:
        cur.execute("SELECT schema_name FROM information_schema.schemata WHERE schema_name = %s", (schema,))
        assert cur.fetchone() is not None, f"Schema {schema} does not exist"
    cur.close()
    conn.close()
