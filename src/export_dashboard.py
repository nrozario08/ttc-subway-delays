"""Run sql/06_dashboard_exports.sql and save the results for the dashboard.

Writes docs/data.js, which just sets window.DASH so the page also works when it
is opened straight from disk (no web server needed).

    python src/export_dashboard.py
"""
import json
import os
import re
import sqlite3

DB_PATH = os.path.join("data", "ttc.db")
SQL_PATH = os.path.join("sql", "06_dashboard_exports.sql")
OUT_PATH = os.path.join("docs", "data.js")


def read_queries(path):
    """Return {name: sql} using the '-- name: xyz' markers."""
    with open(path) as f:
        text = f.read()
    queries = {}
    for chunk in re.split(r"^-- name:\s*", text, flags=re.M)[1:]:
        name, _, body = chunk.partition("\n")
        queries[name.strip()] = body.strip()
    return queries


def main():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row

    data = {}
    for name, sql in read_queries(SQL_PATH).items():
        rows = [dict(r) for r in con.execute(sql)]
        data[name] = rows
        print(f"{name}: {len(rows)} rows")

    os.makedirs("docs", exist_ok=True)
    with open(OUT_PATH, "w") as f:
        f.write("window.DASH = ")
        json.dump(data, f, separators=(",", ":"))
        f.write(";\n")
    print(f"saved {OUT_PATH}")


if __name__ == "__main__":
    main()
