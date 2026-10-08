import os
import sqlite3
import time
import json
from datetime import datetime, timedelta

DB_PATH = os.path.expanduser("~/.local/share/wellbeing/wellbeing.db")

def get_data():
    if not os.path.exists(DB_PATH):
        return json.dumps({
            "today_total": 0, 
            "today_apps": [], 
            "history": [], 
            "app_switches": 0, 
            "peak_hour": "--:--"
        })
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    today_dt = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    today_ts = today_dt.timestamp()
    
    cursor.execute("""
        SELECT app_class, SUM(end_time - start_time) 
        FROM usage 
        WHERE start_time >= ? 
        GROUP BY app_class 
        ORDER BY SUM(end_time - start_time) DESC
    """, (today_ts,))
    
    today_apps = []
    today_total = 0
    
    for row in cursor.fetchall():
        app_class = row[0]
        duration = row[1]
        if not app_class:
            continue
        today_total += duration
        today_apps.append({
            "app": app_class,
            "duration": duration
        })
        
    cursor.execute("SELECT start_time, end_time FROM usage WHERE start_time >= ?", (today_ts,))
    hourly_usage = {}
    app_switches = 0
    
    for row in cursor.fetchall():
        app_switches += 1
        dt = datetime.fromtimestamp(row[0])
        hour_label = dt.strftime("%I %p").lstrip("0")
        hourly_usage[hour_label] = hourly_usage.get(hour_label, 0) + (row[1] - row[0])
        
    peak_hour = max(hourly_usage, key=hourly_usage.get) if hourly_usage else "--:--"
        
    history = []
    for i in range(6, -1, -1):
        day_start_dt = today_dt - timedelta(days=i)
        day_end_dt = day_start_dt + timedelta(days=1)
        day_start_ts = day_start_dt.timestamp()
        day_end_ts = day_end_dt.timestamp()
        
        cursor.execute("""
            SELECT app_class, SUM(end_time - start_time) 
            FROM usage 
            WHERE start_time >= ? AND start_time < ?
            GROUP BY app_class
            ORDER BY SUM(end_time - start_time) DESC
        """, (day_start_ts, day_end_ts))
        
        day_apps = []
        day_total = 0
        top_app = ""
        
        for idx, row in enumerate(cursor.fetchall()):
            app_class = row[0]
            duration = row[1]
            if not app_class:
                continue
            if idx == 0:
                top_app = app_class
            day_total += duration
            day_apps.append({
                "app": app_class,
                "duration": duration
            })
        
        history.append({
            "day": day_start_dt.strftime("%a"),
            "total": day_total,
            "top_app": top_app,
            "apps": day_apps
        })
        
    conn.close()
    
    return json.dumps({
        "today_total": today_total,
        "today_apps": today_apps,
        "history": history,
        "app_switches": app_switches,
        "peak_hour": peak_hour
    })

if __name__ == "__main__":
    print(get_data())