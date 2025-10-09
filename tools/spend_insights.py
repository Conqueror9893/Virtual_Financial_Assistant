# tools/spend_insights.py
import pandas as pd
from datetime import datetime
from functools import lru_cache

from utils import logger

logger = logger.get_logger("SpendInsightsTool")
EXCEL_PATH = "data/transactions.xlsx"

@lru_cache(maxsize=1)
def load_transactions() -> pd.DataFrame:
    """Load and cache the transactions Excel."""
    df = pd.read_excel(EXCEL_PATH, parse_dates=["TXN_DATE"])
    # Normalize column names if needed
    df["genify_category"] = df["genify_category"].fillna("Uncategorized")
    df["genify_clean_description"] = df["genify_clean_description"].fillna("")
    return df

def filter_transactions(start_date=None, end_date=None, category=None, merchant=None):
    df = load_transactions()
    if start_date:
        df = df[df["TXN_DATE"] >= pd.to_datetime(start_date)]
    if end_date:
        df = df[df["TXN_DATE"] <= pd.to_datetime(end_date)]
    if category:
        df = df[df["genify_category"].str.lower() == category.lower()]
    if merchant:
        df = df[df["genify_clean_description"].str.contains(merchant, case=False, na=False)]
    return df

def get_total_spend(start_date=None, end_date=None):
    df = filter_transactions(start_date, end_date)
    logger.info("Total transactions found: %d", len(df["TXN_AMOUNT_LCY"]))
    return df["TXN_AMOUNT_LCY"].sum()

def get_category_spend(category, start_date=None, end_date=None):
    df = filter_transactions(start_date, end_date, category)
    return df["TXN_AMOUNT_LCY"].sum()

def get_top_merchants(category=None, start_date=None, end_date=None, limit=5):
    df = filter_transactions(start_date, end_date, category)
    grouped = df.groupby("genify_clean_description")["TXN_AMOUNT_LCY"].sum().reset_index()
    return grouped.sort_values("TXN_AMOUNT_LCY", ascending=False).head(limit).to_dict(orient="records")

def get_spend_breakdown(start_date=None, end_date=None):
    df = filter_transactions(start_date, end_date)
    grouped = df.groupby("genify_category")["TXN_AMOUNT_LCY"].sum().reset_index()
    return grouped.to_dict(orient="records")
