"""Load the raw TTC delay files into a SQLite database (data/ttc.db).

Only light work happens here: stack the yearly files together and store them in
a table called delays_raw. The actual cleaning is done in SQL (sql/01_clean.sql).

    python src/build_db.py
"""
import glob
import os
import sqlite3

import pandas as pd

RAW_DIR = os.path.join("data", "raw")
DB_PATH = os.path.join("data", "ttc.db")

KEEP = ["Date", "Time", "Day", "Station", "Code", "Min Delay", "Min Gap", "Bound", "Line", "Vehicle"]


def load_delay_files():
    frames = []
    for path in sorted(glob.glob(os.path.join(RAW_DIR, "delays_*"))):
        if path.endswith(".xlsx"):
            # 2019-2021 have one sheet per month, newer files have a single sheet
            sheets = pd.read_excel(path, sheet_name=None)
            df = pd.concat(sheets.values(), ignore_index=True)
        else:
            df = pd.read_csv(path)

        df.columns = [str(c).strip() for c in df.columns]
        df = df[[c for c in KEEP if c in df.columns]].copy()
        df["source_file"] = os.path.basename(path)
        print(f"{os.path.basename(path)}: {len(df):,} rows")
        frames.append(df)
    return pd.concat(frames, ignore_index=True)


def main():
    delays = load_delay_files()

    # dates come through as timestamps in the excel files and strings in the csv
    delays["Date"] = pd.to_datetime(delays["Date"], errors="coerce").dt.strftime("%Y-%m-%d")

    codes = pd.read_csv(os.path.join(RAW_DIR, "delay_codes.csv")).drop(columns=["_id"], errors="ignore")
    codes.columns = [c.lower() for c in codes.columns]

    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    with sqlite3.connect(DB_PATH) as con:
        delays.to_sql("delays_raw", con, index=False)
        codes.to_sql("delay_codes", con, index=False)
    print(f"wrote {len(delays):,} rows to {DB_PATH}")


if __name__ == "__main__":
    main()
