#!/bin/bash

# Force UTF-8 encoding to handle emojis
export LANG=en_US.UTF-8

echo -e "\e[36m🚀 INITIALIZING GRID+ CENTRAL HUB INSTALLATION (RASPBERRY PI/LINUX)...\e[0m"

# 1. Directory Initialization
ROOT_DIR="$HOME/energy_logger"
mkdir -p "$ROOT_DIR/scripts" "$ROOT_DIR/data" "$ROOT_DIR/logs"
echo -e "\e[32m✅ Created directory structure at $ROOT_DIR\e[0m"
cd "$ROOT_DIR" || exit

# 2. System Readiness & Dependencies
echo -e "\e[33m📦 Updating package lists and installing Python venv...\e[0m"
sudo apt-get update -y > /dev/null 2>&1
# Linux requires the python3-venv package explicitly
sudo apt-get install -y python3-pip python3-venv > /dev/null 2>&1

# 3. Virtual Environment
if [ ! -d "venv" ]; then
    echo -e "\e[33m📦 Creating Virtual Environment...\e[0m"
    python3 -m venv venv
fi

# Activate environment
source venv/bin/activate

echo -e "\e[33m📥 Installing Dependencies (Flask, PySerial)...\e[0m"
pip install flask pyserial > /dev/null 2>&1
echo -e "\e[32m✅ Dependencies Installed!\e[0m"

# 4. Script Generation: HTTP Receiver (ESP32)
echo -e "\e[33m📝 Generating Edge Processing Scripts...\e[0m"

# Using 'EOF' prevents bash from interpreting Python syntax
cat << 'EOF' > "$ROOT_DIR/scripts/http_receiver.py"
import os
import csv
import time
from flask import Flask, request
from datetime import datetime

app = Flask(__name__)
# Uses the Linux home directory dynamically
DATA_DIR = os.path.expanduser("~/energy_logger/data")
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
EOF
# 5. Script Generation: Bluetooth Logger (Arduino)
echo -e "\e[33m📝 Generating Bluetooth Logger Script...\e[0m"
cat << 'EOF' > "$ROOT_DIR/scripts/bt_logger.py"
import serial
import time
import os
import csv
from datetime import datetime

# On Linux/Pi, Bluetooth serial is usually mapped to /dev/rfcomm0
COM_PORT = '/dev/rfcomm0' 
BAUD_RATE = 9600
DATA_DIR = os.path.expanduser("~/energy_logger/data")

def get_daily_filename():
    date_str = datetime.now().strftime("%Y-%m-%d")
    return os.path.join(DATA_DIR, f"arduino_bt_data_{date_str}.csv")

try:
    print(f"📡 Attempting to connect to {COM_PORT}...")
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    time.sleep(2)
    print(f"✅ Connected! Logging Arduino data to CSV...")

    while True:
        if ser.in_waiting > 0:
            line = ser.readline().decode('utf-8').rstrip()
            
            # Ensure the line isn't empty before logging
            if line:
                log_file = get_daily_filename()
                file_exists = os.path.isfile(log_file)
                
                with open(log_file, "a", newline="") as f:
                    writer = csv.writer(f)
                    
                    # Write Header only if file is new
                    if not file_exists:
                        writer.writerow(["Timestamp", "Sensor_1", "Sensor_2", "Sensor_3"])
                        
                    # Append timestamp + comma-separated data payload
                    writer.writerow([datetime.now().isoformat()] + line.split(","))
                
                print(f"📦 Logged to CSV: {line}")
            
except serial.SerialException as e:
    print(f"❌ Connection Error: {e}")
    print("💡 Tip: On Linux, ensure you paired the HC-05 and ran: sudo rfcomm bind 0 <MAC_ADDRESS>")
except KeyboardInterrupt:
    print("\n🛑 Logging Stopped by User")
finally:
    if 'ser' in locals() and ser.is_open:
        ser.close()
EOF

echo -e "\e[36m🏁 INSTALLATION COMPLETE!\e[0m"
echo "------------------------------------------------"
echo -e "\e[32m👉 To activate the hub environment run:  source ~/energy_logger/venv/bin/activate\e[0m"
echo -e "\e[32m👉 To start the Wi-Fi Hub run:           python ~/energy_logger/scripts/http_receiver.py\e[0m"
echo -e "\e[32m👉 To start the Bluetooth Logger run:    python ~/energy_logger/scripts/bt_logger.py\e[0m"
echo "------------------------------------------------"
