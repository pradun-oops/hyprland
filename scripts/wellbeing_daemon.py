import os
import socket
import sqlite3
import time
import signal
import sys

DB_DIR = os.path.expanduser("~/.local/share/wellbeing")
DB_PATH = os.path.join(DB_DIR, "wellbeing.db")
os.makedirs(DB_DIR, exist_ok=True)

conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()
cursor.execute("CREATE TABLE IF NOT EXISTS usage (id INTEGER PRIMARY KEY, app_class TEXT, start_time REAL, end_time REAL)")
conn.commit()

xdg_runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
sock_path = f"{xdg_runtime}/hypr/{signature}/.socket2.sock"

current_app = None
start_time = time.time()

def log_usage(app, start, end):
    if app and end > start:
        cursor.execute("INSERT INTO usage (app_class, start_time, end_time) VALUES (?, ?, ?)", (app, start, end))
        conn.commit()

def graceful_exit(sig, frame):
    if current_app:
        log_usage(current_app, start_time, time.time())
    conn.close()
    sys.exit(0)

signal.signal(signal.SIGINT, graceful_exit)
signal.signal(signal.SIGTERM, graceful_exit)

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
    client.connect(sock_path)
    buffer = ""
    while True:
        data = client.recv(4096).decode("utf-8")
        if not data:
            break
        buffer += data
        while "\n" in buffer:
            line, buffer = buffer.split("\n", 1)
            if line.startswith("activewindow>>"):
                parts = line.split(">>")[1].split(",")
                new_app = parts[0] if parts else ""
                
                now = time.time()
                if current_app != new_app:
                    log_usage(current_app, start_time, now)
                    current_app = new_app
                    start_time = now