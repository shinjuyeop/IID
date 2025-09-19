from flask import Flask, render_template_string, jsonify
import adafruit_dht
import board
import threading, time, sys

app = Flask(__name__)

dht = adafruit_dht.DHT11(board.D23)

# === 공유 변수 ===
latest_temp = None
latest_humid = None

def sensor_loop():
    global latest_temp, latest_humid
    while True:
        try:
            t = dht.temperature
            h = dht.humidity
            if t is not None and h is not None:
                latest_temp = t
                latest_humid = h
                print(f"[DEBUG] 최신값 업데이트됨: Temp={latest_temp}, Humid={latest_humid}")
        except RuntimeError as e:
            print(f"[ERROR] RuntimeError 발생: {e}", file=sys.stderr)
        except Exception as e:
            print(f"[ERROR] 기타 예외 발생: {e}", file=sys.stderr)
        time.sleep(2)

threading.Thread(target=sensor_loop, daemon=True).start()

# === HTML 템플릿 ===
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>DHT11 온/습도 모니터링</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background-color: #f4f7f9; }
        h1 { margin-bottom: 20px; }
        .status-box { 
            margin: 20px auto; padding: 20px; border: 2px solid #333; 
            border-radius: 10px; background: #fff; width: 300px;
            box-shadow: 2px 2px 10px rgba(0,0,0,0.2);
        }
        .value { font-size: 22px; font-weight: bold; margin: 10px 0; }
        .temp { color: #007BFF; }
        .humid { color: #28A745; }
    </style>
</head>
<body>
    <h1>4번 과제: 온/습도 센서 모니터링</h1>
    <div class="status-box">
        <h2>Sensor Data</h2>
        <p class="value temp">🌡 온도: <span id="temp">--</span> °C</p>
        <p class="value humid">💧 습도: <span id="humid">--</span> %</p>
    </div>

    <script>
        async function fetchData() {
            try {
                const response = await fetch("/sensor_data");
                const data = await response.json();
                console.log("[DEBUG] /sensor_data 응답:", data);
                document.getElementById("temp").innerText = data.temperature !== null ? data.temperature.toFixed(1) : "--";
                document.getElementById("humid").innerText = data.humidity !== null ? data.humidity.toFixed(1) : "--";
            } catch (e) {
                console.error("[ERROR] fetch 실패:", e);
                document.getElementById("temp").innerText = "--";
                document.getElementById("humid").innerText = "--";
            }
        }
        setInterval(fetchData, 1000);
        fetchData();
    </script>
</body>
</html>
"""

@app.route("/")
def home():
    return render_template_string(HTML_TEMPLATE)

@app.route("/sensor_data")
def sensor_data():
    print(f"[DEBUG] /sensor_data 요청 처리: latest_temp={latest_temp}, latest_humid={latest_humid}")
    return jsonify({"temperature": latest_temp, "humidity": latest_humid})

if __name__ == "__main__":
    try:
        print("[INFO] Flask 서버 시작...")
        app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False)
    finally:
        dht.exit()
