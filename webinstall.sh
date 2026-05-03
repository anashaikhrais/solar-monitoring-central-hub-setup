#!/bin/bash

export LANG=en_US.UTF-8
echo -e "\e[36m🌐 INITIALIZING GRID+ WEB DASHBOARD V2...\e[0m"

ROOT_DIR="$HOME/energy_logger"
mkdir -p "$ROOT_DIR/templates"

# 1. Backend Server
cat << 'EOF' > "$ROOT_DIR/dashboard_server.py"
import os
import csv
import glob
from flask import Flask, jsonify, render_template

app = Flask(__name__)
DATA_DIR = os.path.expanduser("~/energy_logger/data")

def get_latest_csv(prefix):
    files = glob.glob(os.path.join(DATA_DIR, f"{prefix}*.csv"))
    if not files: return []
    latest_file = max(files, key=os.path.getctime)
    data = []
    with open(latest_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader: data.append(row)
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
    print("🌐 Server live! Go to http://127.0.0.1:8080 on the Pi")
    app.run(host='0.0.0.0', port=8080, debug=False)
EOF

# 2. Frontend Interface (Upgraded with Sun Gauge)
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
        body { background-color: var(--bg-color); color: var(--text-main); font-family: 'Segoe UI', sans-serif; margin: 0; padding: 20px; }
        .header { text-align: center; margin-bottom: 20px; }
        h1 { color: #38bdf8; font-size: 24px; }
        .dashboard-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; max-width: 1200px; margin: 0 auto; }
        .panel { background-color: var(--panel-bg); border-radius: 12px; padding: 20px; }
        .panel-header { font-size: 18px; font-weight: bold; margin-bottom: 15px; display: flex; align-items: center; gap: 10px; }
        .blue-dot { color: var(--accent-blue); }
        .green-dot { color: var(--accent-green); }
        .data-card { background-color: #0f172a; border-radius: 8px; padding: 15px; text-align: center; margin-bottom: 10px; }
        .data-label { color: var(--text-muted); font-size: 14px; }
        .data-value { font-size: 24px; font-weight: bold; margin-top: 5px; }
        .highlight-yellow { color: var(--accent-yellow); font-size: 28px; }
        .highlight-green { color: var(--accent-green); }
        .chart-container { position: relative; height: 250px; width: 100%; margin-top: 20px; }
        
        /* Sun Gauge CSS */
        .sun-gauge-container { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 20px 0; }
        .sun-gauge { width: 120px; height: 120px; border-radius: 50%; border: 4px solid #1e293b; background: #0b101e; position: relative; }
        .sun-pointer { position: absolute; top: 10%; left: 48%; width: 4px; height: 40%; background: var(--accent-yellow); transform-origin: bottom center; transform: rotate(0deg); transition: transform 0.5s cubic-bezier(0.4, 0, 0.2, 1); }
        .triangle-up { width: 0; height: 0; border-left: 10px solid transparent; border-right: 10px solid transparent; border-bottom: 15px solid var(--accent-green); margin: 15px 0 5px 0; }
    </style>
</head>
<body>
    <div class="header"><h1>⚡ Live Energy Monitoring Dashboard</h1></div>
    <div class="dashboard-grid">
        <div class="panel">
            <div class="panel-header"><span class="blue-dot">🔵</span> Arduino Panel</div>
            <div class="data-card"><div class="data-label">Voltage</div><div class="data-value" id="ard-volt">-- V</div></div>
            <div class="data-card"><div class="data-label">Current</div><div class="data-value" id="ard-curr">-- A</div></div>
            <div class="data-card"><div class="data-label">Power</div><div class="data-value highlight-yellow" id="ard-power">-- W</div></div>
            
            <!-- New Sun Gauge Component -->
            <div class="data-card sun-gauge-container">
                <div class="sun-gauge"><div class="sun-pointer" id="sun-pointer"></div></div>
                <div class="triangle-up"></div>
                <div class="data-value highlight-green" id="ard-angle" style="font-size: 18px;">0&deg;</div>
            </div>

            <div class="panel-header" style="margin-top: 30px;">📈 Arduino Trends</div>
            <div class="chart-container"><canvas id="arduinoChart"></canvas></div>
        </div>
        <div class="panel">
            <div class="panel-header"><span class="green-dot">🟢</span> ESP32 Panel</div>
            <div class="data-card"><div class="data-label">Current</div><div class="data-value" id="esp-curr">-- A</div></div>
            <div class="data-card"><div class="data-label">Temperature</div><div class="data-value" id="esp-temp">-- &deg;C</div></div>
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
            data: { labels: [], datasets: [{ label: 'Voltage (V)', borderColor: '#3b82f6', data: [], tension: 0.4 }] },
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
                    espChart.data.labels = data.esp32.map(row => row['Timestamp'].split(' ')[1].substring(0,8));
                    espChart.data.datasets[0].data = data.esp32.map(row => parseFloat(row['Current (A)']));
                    espChart.update();
                }

                if (data.arduino.length > 0) {
                    const latestArd = data.arduino[data.arduino.length - 1];
                    
                    // NOTE: Change 'Sensor_1', 'Sensor_2', etc., to match the actual headers in your Arduino CSV file!
                    document.getElementById('ard-volt').innerText = (latestArd['Sensor_1'] || 0) + ' V';
                    document.getElementById('ard-curr').innerText = (latestArd['Sensor_2'] || 0) + ' A';
                    document.getElementById('ard-power').innerText = (latestArd['Sensor_3'] || 0) + ' W';
                    
                    // Update Sun Gauge Animation
                    // Assuming you add an 'Angle' column to your Arduino CSV. For now, it fakes it using Sensor_3
                    let angleVal = parseFloat(latestArd['Sensor_3'] || 0); 
                    document.getElementById('ard-angle').innerText = angleVal + '°';
                    document.getElementById('sun-pointer').style.transform = `rotate(${angleVal}deg)`;
                    
                    arduinoChart.data.labels = data.arduino.map(row => row['Timestamp'].split(' ')[1].substring(0,8));
                    arduinoChart.data.datasets[0].data = data.arduino.map(row => parseFloat(row['Sensor_1']));
                    arduinoChart.update();
                }
            } catch (error) {}
        }
        setInterval(fetchLiveData, 2000);
        fetchLiveData();
    </script>
</body>
</html>
EOF
echo -e "\e[32m✅ Update Complete!\e[0m"
