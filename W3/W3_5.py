from flask import Flask, render_template_string, jsonify
import RPi.GPIO as GPIO
import adafruit_dht
import board
import threading, time

# === Flask 앱 ===
app = Flask(__name__)

# === GPIO 설정 ===
GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)

LED_PINS = [17, 27, 22]  # LED1=에어컨, LED2=히터, LED3=제습기
for pin in LED_PINS:
    GPIO.setup(pin, GPIO.OUT, initial=GPIO.LOW)

TRIG, ECHO = 20, 21
GPIO.setup(TRIG, GPIO.OUT)
GPIO.setup(ECHO, GPIO.IN)

TOUCH_PIN = 6
GPIO.setup(TOUCH_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

# === 센서 객체 ===
dht = adafruit_dht.DHT11(board.D23)

# === 상태 변수 ===
latest_temp = None
latest_humid = None
latest_dist = None
led_status = [0, 0, 0]   # LED 상태 저장
mode_auto = True         # 기본 Auto 모드

# === 초음파 센서 읽기 ===
def get_distance():
    GPIO.output(TRIG, False)
    time.sleep(0.0002)
    GPIO.output(TRIG, True)
    time.sleep(0.00001)
    GPIO.output(TRIG, False)

    pulse_start = time.time()
    timeout = pulse_start + 0.04
    while GPIO.input(ECHO) == 0 and time.time() < timeout:
        pulse_start = time.time()

    pulse_end = time.time()
    timeout = pulse_end + 0.04
    while GPIO.input(ECHO) == 1 and time.time() < timeout:
        pulse_end = time.time()

    pulse_duration = pulse_end - pulse_start
    distance = pulse_duration * 17150
    return round(distance, 2)

# === 센서 읽기 스레드 ===
def sensor_loop():
    global latest_temp, latest_humid, latest_dist, led_status, mode_auto
    while True:
        try:
            t = dht.temperature
            h = dht.humidity
            d = get_distance()
            if t is not None and h is not None:
                latest_temp = t
                latest_humid = h
            latest_dist = d

            # === Auto 모드일 경우 자동 제어 ===
            if mode_auto:
                # 에어컨
                if latest_temp is not None and latest_temp >= 25:
                    GPIO.output(LED_PINS[0], GPIO.HIGH); led_status[0] = 1
                else:
                    GPIO.output(LED_PINS[0], GPIO.LOW); led_status[0] = 0
                # 히터
                if latest_temp is not None and latest_temp <= 18:
                    GPIO.output(LED_PINS[1], GPIO.HIGH); led_status[1] = 1
                else:
                    GPIO.output(LED_PINS[1], GPIO.LOW); led_status[1] = 0
                # 제습기
                if latest_humid is not None and latest_humid >= 40:
                    GPIO.output(LED_PINS[2], GPIO.HIGH); led_status[2] = 1
                else:
                    GPIO.output(LED_PINS[2], GPIO.LOW); led_status[2] = 0

        except RuntimeError:
            pass
        except Exception as e:
            print("[ERROR]", e)

        time.sleep(2)

# === 터치센서 Polling 스레드 ===
def touch_loop():
    global mode_auto
    prev_touch = GPIO.input(TOUCH_PIN)
    while True:
        curr_touch = GPIO.input(TOUCH_PIN)
        if prev_touch == 1 and curr_touch == 0:  # Falling edge
            mode_auto = not mode_auto
            print(f"[INFO] 터치센서로 모드 전환됨 → {'AUTO' if mode_auto else 'MANUAL'}")
        prev_touch = curr_touch
        time.sleep(0.05)  # 50ms 간격으로 polling

# === 백그라운드 스레드 실행 ===
threading.Thread(target=sensor_loop, daemon=True).start()
threading.Thread(target=touch_loop, daemon=True).start()

# === HTML 템플릿 ===
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>KU IOT System Controller</title>
    <style>
        body { font-family: Arial, sans-serif; background-color: #eef2f3; text-align: center; }
        .container { margin: 20px auto; padding: 20px; width: 900px; border: 2px solid #2e7d32; border-radius: 15px; background: #fff; box-shadow: 3px 3px 10px rgba(0,0,0,0.2); }
        h1 { margin-bottom: 20px; color: #2e7d32; display: flex; align-items: center; justify-content: center; gap: 10px; }
        h1 img { height: 40px; }
        .status { display: flex; justify-content: space-around; margin: 20px 0; }
        .status div { font-size: 18px; }
        .status img { height: 40px; vertical-align: middle; margin-right: 10px; }
        .mode-toggle { margin: 20px; }
        .mode-indicator { font-weight: bold; font-size: 20px; color: #fff; display: inline-block; padding: 10px 20px; border-radius: 10px; }
        .auto { background: #2e7d32; }
        .manual { background: #c62828; }
        .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin-top: 20px; }
        .device { border: 1px solid #ccc; padding: 20px; border-radius: 10px; background: #fafafa; }
        .device img { height: 50px; margin-bottom: 10px; }
        .on { color: green; font-weight: bold; }
        .off { color: red; font-weight: bold; }
        .alert { background: red; color: white; font-weight: bold; padding: 10px; margin-top: 10px; border-radius: 8px; }
        button { padding: 10px 20px; font-size: 16px; margin: 5px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1><img src="/static/icon/kulogo.gif"> KU IOT System Controller</h1>
        <div class="mode-toggle">
            현재 모드: <span id="mode" class="mode-indicator auto">AUTO</span><br>
            <button onclick="setMode(true)">AUTO</button>
            <button onclick="setMode(false)">MANUAL</button>
        </div>
        <div class="status">
            <div><img src="/static/icon/온도.png"> 온도: <span id="temp">--</span> ℃</div>
            <div><img src="/static/icon/습도.png"> 습도: <span id="humid">--</span> %</div>
            <div><img src="/static/icon/거리.png"> 거리: <span id="dist">--</span> cm</div>
        </div>
        <div id="alert-box"></div>
        <div class="grid">
            <div class="device">
                <img src="/static/icon/에어컨.png">
                <h2>에어컨</h2>
                <p id="ac_status" class="off">--</p>
                <button onclick="controlDevice(0,1)">ON</button>
                <button onclick="controlDevice(0,0)">OFF</button>
            </div>
            <div class="device">
                <img src="/static/icon/히터.png">
                <h2>히터</h2>
                <p id="heater_status" class="off">--</p>
                <button onclick="controlDevice(1,1)">ON</button>
                <button onclick="controlDevice(1,0)">OFF</button>
            </div>
            <div class="device">
                <img src="/static/icon/제습기.png">
                <h2>제습기</h2>
                <p id="dehum_status" class="off">--</p>
                <button onclick="controlDevice(2,1)">ON</button>
                <button onclick="controlDevice(2,0)">OFF</button>
            </div>
        </div>
    </div>

    <script>
        let autoMode = true;

        async function fetchData() {
            const response = await fetch("/status");
            const data = await response.json();
            document.getElementById("temp").innerText = data.temperature ?? "--";
            document.getElementById("humid").innerText = data.humidity ?? "--";
            document.getElementById("dist").innerText = data.distance ?? "--";

            // 상태 표시 (ON=green, OFF=red)
            const acElem = document.getElementById("ac_status");
            acElem.innerText = data.led_status[0] ? "ON" : "OFF";
            acElem.className = data.led_status[0] ? "on" : "off";

            const heaterElem = document.getElementById("heater_status");
            heaterElem.innerText = data.led_status[1] ? "ON" : "OFF";
            heaterElem.className = data.led_status[1] ? "on" : "off";

            const dehumElem = document.getElementById("dehum_status");
            dehumElem.innerText = data.led_status[2] ? "ON" : "OFF";
            dehumElem.className = data.led_status[2] ? "on" : "off";

            // 모드 표시
            autoMode = data.auto_mode;
            const modeElem = document.getElementById("mode");
            if (autoMode) {
                modeElem.innerText = "AUTO";
                modeElem.className = "mode-indicator auto";
            } else {
                modeElem.innerText = "MANUAL";
                modeElem.className = "mode-indicator manual";
            }

            // 경고 표시
            if (data.distance !== null && data.distance <= 10) {
                document.getElementById("alert-box").innerHTML = "<div class='alert'>⚠ 침입자 감지! 너무 가까움!</div>";
            } else {
                document.getElementById("alert-box").innerHTML = "";
            }
        }

        async function controlDevice(id, state) {
            if (!autoMode) {
                await fetch(`/control/${id}/${state}`);
                fetchData();
            } else {
                alert("AUTO 모드에서는 수동 제어 불가!");
            }
        }

        async function setMode(mode) {
            autoMode = mode;
            await fetch(`/set_mode/${mode ? 1 : 0}`);
            fetchData();
        }

        setInterval(fetchData, 2000);
        fetchData();
    </script>
</body>
</html>
"""

@app.route("/")
def home():
    return render_template_string(HTML_TEMPLATE)

@app.route("/status")
def status():
    return jsonify({
        "temperature": latest_temp,
        "humidity": latest_humid,
        "distance": latest_dist,
        "led_status": led_status,
        "auto_mode": mode_auto
    })

@app.route("/control/<int:led_id>/<int:state>")
def control(led_id, state):
    global led_status
    if not mode_auto and 0 <= led_id < 3:
        GPIO.output(LED_PINS[led_id], GPIO.HIGH if state == 1 else GPIO.LOW)
        led_status[led_id] = state
    return ("", 204)

@app.route("/set_mode/<int:mode>")
def set_mode(mode):
    global mode_auto
    mode_auto = (mode == 1)
    print(f"[INFO] 웹에서 모드 전환됨 → {'AUTO' if mode_auto else 'MANUAL'}")
    return ("", 204)

if __name__ == "__main__":
    try:
        app.run(host="0.0.0.0", port=8080, debug=False)
    finally:
        GPIO.cleanup()
