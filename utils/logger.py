# utils/logger.py
import logging
from logging.handlers import RotatingFileHandler
import os

LOG_PATH = os.environ.get("LOG_PATH", "logs/app.log")
os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)

def get_logger(name=__name__):
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)

    if not logger.handlers:
        fh = RotatingFileHandler(LOG_PATH, maxBytes=5*1024*1024, backupCount=5)
        formatter = logging.Formatter('%(asctime)s %(levelname)s %(name)s %(message)s')
        fh.setFormatter(formatter)
        logger.addHandler(fh)

        ch = logging.StreamHandler()
        ch.setFormatter(formatter)
        logger.addHandler(ch)

    return logger
