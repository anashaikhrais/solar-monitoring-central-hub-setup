Write-Host "🚀 INITIALIZING GRID+ CENTRAL HUB INSTALLATION..." -ForegroundColor Cyan

# 1. Directory Initialization
$root = "C:\energy_logger"
$dirs = @("$root", "$root\scripts", "$root\data", "$root\logs")
foreach ($dir in $dirs) {
    if (!(Test-Path $dir)) { 
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "✅ Created directory: $dir" -ForegroundColor Green
    }
}
cd $root

# 2. Python Readiness Check
if (!(Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️ Python not found. Auto-installing via winget..." -ForegroundColor Yellow
    winget install -e --id Python.Python.3 --accept-source-agreements --accept-package-agreements
    Write-Host "🛑 Python installed. PLEASE RESTART POWERSHELL AND RUN THE INSTALL COMMAND AGAIN." -ForegroundColor Red
    return
}

# 3. Virtual Environment & Dependencies
if (!(Test-Path "$root\venv")) {
    Write-Host "📦 Creating Virtual Environment..." -ForegroundColor Yellow
    python -m venv venv
}
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
& "$root\venv\Scripts\Activate.ps1"

Write-Host "📥 Installing Dependencies (Flask, PySerial)..." -ForegroundColor Yellow
pip install flask pyserial | Out-Null
Write-Host "✅ Dependencies Installed!" -ForegroundColor Green

# 4. Script Generation: HTTP Receiver (ESP32)
Write-Host "📝 Generating Edge Processing Scripts..." -ForegroundColor Yellow
$httpCode = @'
import os
import csv
import time
from flask import Flask, request
from datetime import datetime

app = Flask(__name__)
DATA_DIR = r"C:\energy_logger\data"
os.makedirs(DATA_DIR, exist_ok=True)

MIN_INTERVAL = 2.0
last_write_time = 0.0

def get_daily_filename():
    date_str = datetime.now().strftime("%Y-%m-%d")
    return os.path.join(DATA_DIR, f"esp32_solar_data_{date_str}.csv")

@app.route("/esp32", methods=["POST"])
def receive_data():
    global last_write_time
    now = time.time()
    
    if now - last_write_time < MIN_INTERVAL:
        return "SKIPPED", 200
        
    payload = request.data.decode("utf-8").strip()
    
    if payload.count(",") != 2:
        return "BAD FORMAT", 400
        
    log_file = get_daily_filename()
    file_exists = os.path.isfile(log_file)
    
    with open(log_file, "a", newline="") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow(["Timestamp", "Current (A)", "Temperature (C)", "Humidity (%)"])
        writer.writerow([datetime.now().isoformat()] + payload.split(","))
        
    print(f"✅ Data Logged: {payload}")
    last_write_time = now
    return "OK", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
'@
Set-Content -Path "$root\scripts\http_receiver.py" -Value $httpCode

# 5. Script Generation: Bluetooth Tester (Arduino)
$btCode = @'
import serial
import time

# UPDATE THIS with your actual COM port
COM_PORT = 'COM3' 
BAUD_RATE = 9600

try:
    print(f"📡 Attempting to connect to {COM_PORT}...")
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    time.sleep(2)
    print(f"✅ Connected! Waiting for Arduino data...")

    while True:
        if ser.in_waiting > 0:
            line = ser.readline().decode('utf-8').rstrip()
            print(f"📦 BT Data Received: {line}")
            
except serial.SerialException as e:
    print(f"❌ Connection Error: {e}")
except KeyboardInterrupt:
    print("\n🛑 Test Stopped by User")
finally:
    if 'ser' in locals() and ser.is_open:
        ser.close()
'@
Set-Content -Path "$root\scripts\bt_test.py" -Value $btCode

Write-Host "🏁 INSTALLATION COMPLETE!" -ForegroundColor Cyan
Write-Host "------------------------------------------------"
Write-Host "👉 To start the Wi-Fi Hub:  python scripts/http_receiver.py" -ForegroundColor Green
Write-Host "👉 To test the Bluetooth:   python scripts/bt_test.py" -ForegroundColor Green
Write-Host "------------------------------------------------"