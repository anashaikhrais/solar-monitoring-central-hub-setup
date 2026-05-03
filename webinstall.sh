#!/bin/bash

# Force UTF-8 encoding to handle emojis cleanly
export LANG=en_US.UTF-8

echo -e "\e[36m🌐 INITIALIZING GRID+ WEB DASHBOARD INSTALLATION...\e[0m"

# 1. Directory Initialization
ROOT_DIR="$HOME/energy_logger"
mkdir -p "$ROOT_DIR/templates"
echo -e "\e[32m✅ Verified web directories at $ROOT_DIR/templates\e[0m"

# 2. Script Generation: Python Flask Web Server
echo -e "\e[33m📝 Generating Dashboard Server (Backend)...\e[0m"
cat << 'EOF' > "$ROOT_DIR/dashboard_server.py"
import os
import csv
import glob
from flask import Flask, jsonify, render_template

app = Flask(__name__)
DATA_DIR = os.path.expanduser("~/energy_logger/data")

def get_latest_csv(prefix):
    files = glob.glob(os.path.join(DATA_DIR, f"{prefix}*.csv"))
    if not files:
        return []
    latest_file = max(files, key=os.path.getctime)
    
    data = []
    with open(latest_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            data.append(row)
    return data[-20:] if len(data) > 20 else data

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/data')
def get_data():
    return jsonify({
        "esp32": get_latest_csv("esp32_"),
        "arduino": get_latest_csv("arduino_bt_")
    })

if __name__ == '__main__':
    print("🌐 Dashboard live at port 8080")
    app.run(host='0.0.0.0', port=8080, debug=False)
EOF

# 3. Script Generation: HTML/CSS/JS Dashboard
echo -e "\e[33m📝 Generating User Interface (Frontend)...\e[0m"
cat << 'EOF' > "$ROOT_DIR/templates/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Live Energy Monitoring Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        :root {
            --bg-color: #0b101e;
            --panel-bg: #111827;
            --text-main: #ffffff;
            --text-muted: #9ca3af;
            --accent-blue: #3b82f6;
            --accent-green: #10b981;
            --accent-yellow: #fbbf24;
        }
        body {
            background-color: var(--bg-color);
            color: var(--text-main);
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
        }
        .header { text-align: center; margin-bottom: 20px; }
        h1 { color: #38bdf8; font-size: 24px; }
        .dashboard-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            max-width: 1200px;
            margin: 0 auto;
        }
        @media (max-width: 768px) {
            .dashboard-grid { grid-template-columns: 1fr; }
        }
        .panel {
            background-color: var(--panel-bg);
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.3);
        }
        .panel-header {
            font-size: 18px;
            font-weight: bold;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .blue-dot { color: var(--accent-blue); }
        .green-dot { color: var(--accent-green); }
        
        .data-card {
            background-color: #0f172a;
            border-radius: 8px;
            padding: 15px;
            text-align: center;
            margin-bottom: 10px;
        }
        .data-label { color: var(--text-muted); font-size: 14px; }
        .data-value { font-size: 24px; font-weight: bold; margin-top: 5px; }
        .highlight-yellow { color: var(--accent-yellow); font-size: 28px; }
        
        .chart-container {
            position: relative;
            height: 250px;
            width: 100%;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>⚡ Live Energy Monitoring Dashboard</h1>
    </div>
    <div class="dashboard-grid">
        <div class="panel">
            <div class="panel-header"><span class="blue-dot">🔵</span> Arduino Panel</div>
            <div class="data-card"><div class="data-label">Sensor 1</div><div class="data-value" id="ard-s1">--</div></div>
            <div class="data-card"><div class="data-label">Sensor 2</div><div class="data-value" id="ard-s2">--</div></div>
            <div class="data-card"><div class="data-label">Sensor 3</div><div class="data-value highlight-yellow" id="ard-s3">--</div></div>
            <div class="panel-header" style="margin-top: 30px;">📈 Arduino Trends</div>
            <div class="chart-container"><canvas id="arduinoChart"></canvas></div>
        </div>
        <div class="panel">
            <div class="panel-header"><span class="green-dot">🟢</span> ESP32 Panel</div>
            <div class="data-card"><div class="data-label">Current</div><div class="data-value" id="esp-curr">-- A</div></div>
            <div class="data-card"><div class="data-label">Temperature</div><div class="data-value" id="esp-temp">-- °C</div></div>
            <div class="data-card"><div class="data-label">Humidity</div><div class="data-value" id="esp-hum">-- %</div></div>
            <div class="panel-header" style="margin-top: 30px;">📈 ESP32 Trends</div>
            <div class="chart-container"><canvas id="espChart"></canvas></div>
        </div>
    </div>
    <script>
        Chart.defaults.color = '#9ca3af';
        Chart.defaults.borderColor = '#374151';

        const ardCtx = document.getElementById('arduinoChart').getContext('2d');
        const espCtx = document.getElementById('espChart').getContext('2d');

        const arduinoChart = new Chart(ardCtx, {
            type: 'line',
            data: { labels: [], datasets: [{ label: 'Sensor 1 Data', borderColor: '#3b82f6', data: [], tension: 0.4 }] },
            options: { responsive: true, maintainAspectRatio: false }
        });

        const espChart = new Chart(espCtx, {
            type: 'line',
            data: { labels: [], datasets: [{ label: 'ESP Current (A)', borderColor: '#10b981', data: [], tension: 0.4 }] },
            options: { responsive: true, maintainAspectRatio: false }
        });

        async function fetchLiveData() {
            try {
                const response = await fetch('/api/data');
                const data = await response.json();
                
                if (data.esp32.length > 0) {
                    const latestEsp = data.esp32[data.esp32.length - 1];
                    document.getElementById('esp-curr').innerText = latestEsp['Current (A)'] + ' A';
                    document.getElementById('esp-temp').innerText = latestEsp['Temperature (C)'] + ' °C';
                    document.getElementById('esp-hum').innerText = latestEsp['Humidity (%)'] + ' %';
                    
                    espChart.data.labels = data.esp32.map(row => row['Timestamp'].split(' ')[1]);
                    espChart.data.datasets[0].data = data.esp32.map(row => parseFloat(row['Current (A)']));
                    espChart.update();
                }

                if (data.arduino.length > 0) {
                    const latestArd = data.arduino[data.arduino.length - 1];
                    document.getElementById('ard-s1').innerText = latestArd['Sensor_1'];
                    document.getElementById('ard-s2').innerText = latestArd['Sensor_2'];
                    document.getElementById('ard-s3').innerText = latestArd['Sensor_3'];
                    
                    arduinoChart.data.labels = data.arduino.map(row => row['Timestamp'].split(' ')[1]);
                    arduinoChart.data.datasets[0].data = data.arduino.map(row => parseFloat(row['Sensor_1']));
                    arduinoChart.update();
                }
            } catch (error) {
                console.error("Error fetching data:", error);
            }
        }
        setInterval(fetchLiveData, 2000);
        fetchLiveData();
    </script>
</body>
</html>
EOF

echo -e "\e[36m🏁 WEB DASHBOARD INSTALLATION COMPLETE!\e[0m"
echo "------------------------------------------------"
echo -e "\e[32m👉 To start the web server run:  python ~/energy_logger/dashboard_server.py\e[0m"
echo -e "\e[32m👉 Then open a browser to:       http://192.168.137.1:8080\e[0m"
echo "------------------------------------------------"
