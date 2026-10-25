"""Run the queries in a .sql file against data/ttc.db and print the results.

Statements are split on a semicolon at the end of a line, and each statement's
leading "-- Q..." comment is used as its heading.

    python src/run_sql.py sql/02_overview.sql
"""
import sqlite3
import sys

DB_PATH = "data/ttc.db"
MAX_ROWS = 25


def split_statements(text):
    statements, current = [], []
    for line in text.splitlines():
        current.append(line)
        if line.rstrip().endswith(";"):
            statements.append("\n".join(current).strip())
            current = []
    return [s for s in statements if s]


def title_of(statement):
    for line in statement.splitlines():
        if line.startswith("-- Q"):
            return line[3:].strip()
    return "query"


def print_table(cols, rows):
    widths = [len(c) for c in cols]
    text_rows = [[("" if v is None else str(v)) for v in r] for r in rows]
    for r in text_rows:
        widths = [max(w, len(v)) for w, v in zip(widths, r)]
    print("  " + " | ".join(c.ljust(w) for c, w in zip(cols, widths)))
    print("  " + "-+-".join("-" * w for w in widths))
    for r in text_rows:
        print("  " + " | ".join(v.ljust(w) for v, w in zip(r, widths)))


def main():
    path = sys.argv[1]
    with open(path) as f:
        statements = split_statements(f.read())

    con = sqlite3.connect(DB_PATH)
    for stmt in statements:
        cur = con.execute(stmt)
        if cur.description is None:
            continue
        cols = [d[0] for d in cur.description]
        rows = cur.fetchmany(MAX_ROWS)
        print(f"\n{title_of(stmt)}")
        print_table(cols, rows)


if __name__ == "__main__":
    main()
