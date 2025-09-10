# utils/otp.py
import random
import hashlib
import time

OTP_TTL_SECONDS = 120

def generate_otp() -> str:
    return f"{random.randint(100000, 999999)}"

def hash_otp(otp: str) -> str:
    return hashlib.sha256(otp.encode()).hexdigest()

def is_otp_valid(stored_hashed: str, otp: str, created_at_ts: float) -> bool:
    if time.time() - created_at_ts > OTP_TTL_SECONDS:
        return False
    return hash_otp(otp) == stored_hashed
