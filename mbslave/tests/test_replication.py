from __future__ import print_function
import sys
import os
from six import StringIO
from mbslave.replication import (
    Config,
    PacketImporter,
    ReplicationHook,
    remap_schema,
    join_paths,
    sorted_transactions,
    split_paths,
)


def test_remap_schema():
    config = Config(os.devnull)
    config.schemas.mapping['musicbrainz'] = 'mb'
    lines = ['CREATE SCHEMA musicbrainz;\n']
    expected_lines = ['CREATE SCHEMA mb;\n']
    actual_lines = list(remap_schema(config, lines))
    assert expected_lines == actual_lines


def test_join_and_split_paths():
    paths = ['a b', 'c']
    assert paths == split_paths(join_paths(paths))


# Packet 189339 stopped replication with a duplicate key on recording_tag: two
# transactions writing (recording, tag) = (39337622, 77) interleaved, and their
# xid order disagreed with the order their statements were written in. These
# are that packet's statements for that key, with the xids and seqids it
# carried.
PACKET_189339 = [
    (2740411655, 430255920, 'i'),
    (2740411677, 430255936, 'u'),
    (2740411677, 430255937, 'd'),
    (2740411676, 430255939, 'i'),
    (2740411685, 430255941, 'u'),
    (2740411685, 430255942, 'd'),
]


def group_by_xid(statements):
    transactions = {}
    for xid, seqid, op in statements:
        transactions.setdefault(xid, []).append((seqid, op))
    return transactions


def test_transactions_replay_in_commit_order_not_xid_order():
    transactions = group_by_xid(PACKET_189339)
    replayed = [xid for xid, _ in sorted_transactions(transactions)]

    # xid 676 wrote after xid 677 committed, even though 676 sorts first.
    assert replayed == [2740411655, 2740411677, 2740411676, 2740411685]
    assert replayed != sorted(transactions.keys())


def test_transactions_of_one_statement_keep_their_order():
    transactions = group_by_xid([(50, 3, 'i'), (40, 1, 'i'), (60, 2, 'i')])
    assert [seqid for _, [(seqid, _op)] in sorted_transactions(transactions)] == [1, 2, 3]


class FakeCursor(object):
    """Enough of a cursor to run PacketImporter.process() without a database."""

    def __init__(self, rows, executed):
        self._rows = rows
        self._pending = []
        self.executed = executed

    def execute(self, sql, params=None):
        if sql.lstrip().startswith('SELECT'):
            self._pending = list(self._rows)
        else:
            self.executed.append((sql, params))

    def fetchone(self):
        return self._pending.pop(0) if self._pending else None


class FakeDb(object):

    def __init__(self, rows):
        self._rows = rows
        self.executed = []

    def cursor(self):
        return FakeCursor(self._rows, self.executed)

    def commit(self):
        pass


def verb(sql):
    return sql.split(None, 1)[0]


def test_interleaved_transactions_do_not_reinsert_a_live_row():
    """The replay of packet 189339 that the primary key used to reject."""
    rows = []
    for xid, seqid, op in PACKET_189339:
        row = {'recording': 39337622, 'tag': 77, 'count': 1}
        rows.append((
            xid, seqid, 'musicbrainz.recording_tag', op, ['recording', 'tag'],
            None if op == 'i' else row,
            None if op == 'd' else row,
        ))

    db = FakeDb(rows)
    config = Config(os.devnull)
    importer = PacketImporter(
        db, config, set(), set(), 189339, ReplicationHook(config, db, config))
    importer.process()

    applied = [verb(sql) for sql, _ in db.executed if not sql.startswith('TRUNCATE')]
    assert applied == [
        'INSERT', 'UPDATE', 'DELETE',   # xid 655, then xid 677
        'INSERT', 'UPDATE', 'DELETE',   # xid 676, then xid 685
    ]
