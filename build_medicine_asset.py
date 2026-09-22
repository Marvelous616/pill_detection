#!/usr/bin/env python3
"""Build pill_app/assets/medicines.json.gz from datasets/medicine_data.csv + onemg.csv.

Schema per record (compact keys):
  n=name, s=salt, m=manufacturer, c=category, p=price,
  d=description, e=side effects, i=interactions, t=therapeutic class
"""
import csv
import gzip
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATASETS = os.path.join(HERE, "pill_app", "datasets")
OUT_DIR = os.path.join(HERE, "pill_app", "assets")
OUT_PATH = os.path.join(OUT_DIR, "medicines.json.gz")

csv.field_size_limit(sys.maxsize)


def txt(v):
    return (v or "").strip()


def rank(r):
    return sum(len(r.get(k) or "") for k in ("d", "e", "i", "s"))


def build():
    best = {}

    with open(os.path.join(DATASETS, "medicine_data.csv"), newline="",
              encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            n = txt(row.get("product_name"))
            if not n:
                continue
            rec = {
                "n": n,
                "s": txt(row.get("salt_composition")),
                "m": txt(row.get("product_manufactured")),
                "c": txt(row.get("sub_category")),
                "p": txt(row.get("product_price")),
                "d": txt(row.get("medicine_desc")),
                "e": txt(row.get("side_effects")),
                "i": txt(row.get("drug_interactions")),
            }
            key = n.casefold()
            if key not in best or rank(rec) > rank(best[key]):
                best[key] = rec

    merged_from_onemg = 0
    with open(os.path.join(DATASETS, "onemg.csv"), newline="",
              encoding="utf-8", errors="replace") as f:
        for row in csv.DictReader(f):
            n = txt(row.get("Drug_Name"))
            if not n:
                continue
            key = n.casefold()
            fields = {
                "n": n,
                "s": txt(row.get("Salt_Composition")) or txt(row.get("salt_composition")),
                "m": txt(row.get("Manufacturer")) or txt(row.get("Marketer")),
                "c": txt(row.get("Therapeutic_Class")),
                "p": txt(row.get("MRP")),
                "d": txt(row.get("Product_Introduction")) or txt(row.get("Uses")),
                "e": txt(row.get("Common_Side_Effects")),
                "i": txt(row.get("Alcohol_Interaction")),
                "t": txt(row.get("Therapeutic_Class")),
            }
            if key in best:
                cur = best[key]
                for k, v in fields.items():
                    if v and (not cur.get(k) or len(v) > len(cur[k])):
                        cur[k] = v
                if fields.get("t") and not cur.get("t"):
                    cur["t"] = fields["t"]
            else:
                best[key] = fields
                merged_from_onemg += 1

    recs = sorted(best.values(), key=lambda r: r["n"].casefold())
    payload = json.dumps(recs, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    gz = gzip.compress(payload, compresslevel=9, mtime=0)

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT_PATH, "wb") as f:
        f.write(gz)

    print(f"records: {len(recs)} (from onemg only: {merged_from_onemg})")
    print(f"raw json: {len(payload)/1e6:.1f} MB -> gzipped: {len(gz)/1e6:.2f} MB")
    print(f"out: {OUT_PATH}")


if __name__ == "__main__":
    build()