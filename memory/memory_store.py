# memory/memory_store.py
import os
import time
import mysql.connector
from mysql.connector import pooling
from utils.logger import get_logger

logger = get_logger(__name__)

DB_CONFIG = {
    "host": os.environ.get("MYSQL_HOST", "localhost"),
    "user": os.environ.get("MYSQL_USER", "root"),
    "password": os.environ.get("MYSQL_PASSWORD", ""),
    "database": os.environ.get("MYSQL_DB", "vfa"),
    "port": int(os.environ.get("MYSQL_PORT", "3306")),
}

# Connection pool
cnxpool = pooling.MySQLConnectionPool(pool_name="vfa_pool", pool_size=5, **DB_CONFIG)

def init_db():
    conn = cnxpool.get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS beneficiaries (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100),
            nickname VARCHAR(100),
            account VARCHAR(50)
        )
        """)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS pending_otp (
            txn_id VARCHAR(64) PRIMARY KEY,
            hashed_otp VARCHAR(64),
            created_at DOUBLE
        )
        """)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS transfers (
            id INT AUTO_INCREMENT PRIMARY KEY,
            txn_id VARCHAR(64),
            session_id VARCHAR(64),
            beneficiary_id INT,
            amount DECIMAL(12,2),
            status VARCHAR(32),
            created_at DOUBLE,
            FOREIGN KEY (beneficiary_id) REFERENCES beneficiaries(id)
        )
        """)
        conn.commit()
    finally:
        cursor.close()
        conn.close()

def find_beneficiary_by_nickname(nickname: str):
    conn = cnxpool.get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM beneficiaries WHERE nickname LIKE %s LIMIT 5", (f"%{nickname}%",))
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()

def insert_pending_otp(txn_id: str, hashed: str, created_at: float):
    conn = cnxpool.get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "REPLACE INTO pending_otp (txn_id, hashed_otp, created_at) VALUES (%s, %s, %s)",
            (txn_id, hashed, created_at)
        )
        conn.commit()
    finally:
        cursor.close()
        conn.close()

def get_pending_otp(txn_id: str):
    conn = cnxpool.get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT hashed_otp, created_at FROM pending_otp WHERE txn_id=%s", (txn_id,))
        return cursor.fetchone()
    finally:
        cursor.close()
        conn.close()

def persist_transfer(txn_id, session_id, beneficiary_id, amount, status, created_at):
    conn = cnxpool.get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO transfers (txn_id, session_id, beneficiary_id, amount, status, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (txn_id, session_id, beneficiary_id, amount, status, created_at))
        conn.commit()
    finally:
        cursor.close()
        conn.close()
