"""Irish baby names analysis.

1. Loads the raw CSO tables VSA50 (boys) and VSA60 (girls), "Names in
   Ireland with 3 or More Occurrences", into a SQLite database.
2. Cleans them with sql/01_clean.sql.
3. Runs the queries in sql/02_analysis.sql.
4. Writes the numbers the site uses to docs/data.json.

Download fresh copies of the data with:
  curl -o data/VSA50.csv https://ws.cso.ie/public/api.restful/PxStat.Data.Cube_API.ReadDataset/VSA50/CSV/1.0/en
  curl -o data/VSA60.csv https://ws.cso.ie/public/api.restful/PxStat.Data.Cube_API.ReadDataset/VSA60/CSV/1.0/en
"""
import csv
import json
import re
import sqlite3

DB = "data/baby_names.db"
FADAS_FROM = 2018  # the CSO data only records fadas from 2018 on
TRENDS = {
    "boys": ["Jack", "Seán", "Rían", "Noah", "John"],
    "girls": ["Mary", "Emily", "Grace", "Fiadh", "Lily"],
}


def load_raw(con, table, path):
    """Load a CSO CSV into SQLite exactly as downloaded."""
    con.execute(f"DROP TABLE IF EXISTS {table}")
    con.execute(f"CREATE TABLE {table} (statistic TEXT, statistic_label TEXT, tlist TEXT, year TEXT, code TEXT, name TEXT, unit TEXT, value TEXT)")
    with open(path, encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        next(reader)  # header
        con.executemany(f"INSERT INTO {table} VALUES (?, ?, ?, ?, ?, ?, ?, ?)", reader)


def named_queries(path):
    """Split a .sql file into {name: sql} on its '-- name:' lines."""
    text = open(path, encoding="utf-8").read()
    parts = re.split(r"^-- name: (\w+)\s*$", text, flags=re.M)
    return {parts[i]: parts[i + 1].strip() for i in range(1, len(parts), 2)}


def fold(name):
    """Same fada folding as the names_merged view, for looking up a trend."""
    return name.translate(str.maketrans("áéíóúÁÉÍÓÚ", "aeiouAEIOU"))


con = sqlite3.connect(DB)
con.row_factory = sqlite3.Row
load_raw(con, "raw_boys", "data/VSA50.csv")
load_raw(con, "raw_girls", "data/VSA60.csv")
con.executescript(open("sql/01_clean.sql", encoding="utf-8").read())
con.commit()

Q = named_queries("sql/02_analysis.sql")
run = lambda name, **p: [dict(r) for r in con.execute(Q[name], p)]

out = {}
for sex in ["boys", "girls"]:
    years = run("years", sex=sex)[0]
    first, last = years["first_year"], years["last_year"]
    decade_ago = last - 10
    params = dict(sex=sex, last=last, decade_ago=decade_ago)

    moves = run("moves", **params)
    for m in moves:
        m["diff"] = m["now_babies"] - m["then_babies"]
    as_move = lambda m: {"name": m["name"], "then": m["then_babies"], "now": m["now_babies"], "diff": m["diff"]}

    diversity = run("diversity", sex=sex)
    out[sex] = {
        "first_year": first,
        "last_year": last,
        "decade_ago": decade_ago,
        "fadas_from": FADAS_FROM,
        "total_last": diversity[-1]["babies"],
        "top10": [{"name": r["name"], "count": r["babies"], "rank": r["rank"]} for r in run("top10", **params)],
        "top_by_year": [{"year": r["year"], "name": r["name"], "count": r["babies"]} for r in run("number_ones", sex=sex)],
        "risers": [as_move(m) for m in sorted(moves, key=lambda m: -m["diff"])[:8]],
        "fallers": [as_move(m) for m in sorted(moves, key=lambda m: m["diff"])[:8]],
        "diversity": [{k: d[k] for k in ("year", "names", "top10_share", "fada_share")} for d in diversity],
        "trends": {
            n: [{"year": r["year"], "count": r["babies"]} for r in run("trend", sex=sex, name_key=fold(n))]
            for n in TRENDS[sex]
        },
    }

json.dump(out, open("docs/data.json", "w"), ensure_ascii=False, indent=1)

for sex, o in out.items():
    print(sex, o["first_year"], "to", o["last_year"])
    print("  top 3:", [(t["name"], t["count"]) for t in o["top10"][:3]])
    print("  risers:", [(r["name"], r["then"], r["now"]) for r in o["risers"][:4]])
    print("  fallers:", [(r["name"], r["then"], r["now"]) for r in o["fallers"][:4]])
    print("  latest:", o["diversity"][-1])
