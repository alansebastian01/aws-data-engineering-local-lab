#!/usr/bin/env python3
"""Generate a realistic synthetic retail dataset using only Python stdlib."""
import argparse, csv, random
from datetime import datetime, timedelta
from pathlib import Path

FIRST = ["Ava","Liam","Noah","Emma","Olivia","Mia","Ethan","Lucas","Sophia","Amelia","Mateo","Aria"]
LAST = ["Smith","Johnson","Brown","Garcia","Miller","Davis","Wilson","Martinez","Anderson","Taylor"]
CITIES = [("Seattle","WA"),("Austin","TX"),("Chicago","IL"),("Miami","FL"),("Boston","MA"),("Denver","CO"),("San Jose","CA"),("Phoenix","AZ")]
CATEGORIES = ["Electronics","Home","Sports","Books","Beauty","Office","Garden","Toys"]
STATUS = ["COMPLETE","COMPLETE","COMPLETE","SHIPPED","CANCELLED","RETURNED"]
PAYMENTS = ["CARD","CARD","PAYPAL","BANK_TRANSFER","WALLET"]

def write_csv(path, header, rows):
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(header); w.writerows(rows)

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--orders", type=int, default=100000)
    p.add_argument("--customers", type=int, default=12000)
    p.add_argument("--products", type=int, default=800)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", default="datasets/generated")
    a=p.parse_args(); random.seed(a.seed)
    out=Path(a.out); out.mkdir(parents=True, exist_ok=True)
    base=datetime(2024,1,1)
    now=datetime(2026,8,1)

    customers=[]
    for cid in range(1,a.customers+1):
        fn,ln=random.choice(FIRST),random.choice(LAST); city,state=random.choice(CITIES)
        signup=base-timedelta(days=random.randint(0,730)); updated=signup+timedelta(days=random.randint(0,600))
        customers.append([cid,f"{fn} {ln}",f"{fn.lower()}.{ln.lower()}{cid}@example.com",city,state,signup.date().isoformat(),updated.strftime("%Y-%m-%d %H:%M:%S")])
    write_csv(out/"customers.csv",["customer_id","customer_name","email","city","state_code","signup_date","updated_at"],customers)

    products=[]
    prices={}
    for pid in range(1,a.products+1):
        cat=random.choice(CATEGORIES); cost=round(random.uniform(2,450),2); price=round(cost*random.uniform(1.15,2.4),2); prices[pid]=price
        products.append([pid,f"{cat} Product {pid}",cat,cost,price,now.strftime("%Y-%m-%d %H:%M:%S")])
    write_csv(out/"products.csv",["product_id","product_name","category","unit_cost","unit_price","updated_at"],products)

    orders=[]; items=[]; item_id=1
    span=(now-base).days
    for oid in range(1,a.orders+1):
        cid=random.randint(1,a.customers); ots=base+timedelta(days=random.randint(0,span),seconds=random.randint(0,86399)); st=random.choice(STATUS); pay=random.choice(PAYMENTS)
        orders.append([oid,cid,ots.strftime("%Y-%m-%d %H:%M:%S"),st,pay,ots.strftime("%Y-%m-%d %H:%M:%S")])
        for _ in range(random.randint(1,4)):
            pid=random.randint(1,a.products); qty=random.randint(1,5); discount=round(prices[pid]*qty*random.choice([0,0,0,.05,.1,.15]),2)
            items.append([item_id,oid,pid,qty,prices[pid],discount,ots.strftime("%Y-%m-%d %H:%M:%S")]); item_id+=1
    write_csv(out/"orders.csv",["order_id","customer_id","order_ts","status","payment_method","updated_at"],orders)
    write_csv(out/"order_items.csv",["order_item_id","order_id","product_id","quantity","unit_price","discount_amount","updated_at"],items)
    print(f"Generated {len(customers):,} customers, {len(products):,} products, {len(orders):,} orders, {len(items):,} line items in {out}")
if __name__ == "__main__": main()
