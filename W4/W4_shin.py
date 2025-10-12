from flask import Flask, render_template_string, jsonify
from flask_cors import CORS
import RPi.GPIO as GPIO
import adafruit_dht, board
import threading, time
import mariadb

# =========================
# DB 설정
# =========================
DB_CONFIG = dict(
    user="team04",
    password="team04",
    host="localhost",
    port=3306,
    database="IOT"
)

def get_db():
    # 간단 커넥션 헬퍼
    conn = mariadb.connect(**DB_CONFIG)
    return conn

def db_init():
    # 테이블 없으면 생성
    sql = """
    CREATE TABLE IF NOT EXISTS sensor_log(
        id INT AUTO_INCREMENT PRIMARY KEY,
        temp  DECIMAL(5,2) NULL,
        humid DECIMAL(5,2) NULL,
        dist  DECIMAL(6,2) NULL,
        dt DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    """
    conn = get_db()
    cur = conn.cursor()
    cur.execute(sql)
    conn.commit()
    cur.close()
    conn.close()

def db_insert(temp, humid, dist):
    conn = get_db()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO sensor_log (temp, humid, dist) VALUES (%s, %s, %s)",
        (None if temp is None else float(temp),
         None if humid is None else float(humid),
         None if dist is None else float(dist))
    )
    conn.commit()
    cur.close()
    conn.close()

def db_last_n(n=10):
    # 최근 n개 (최신→과거) 반환
    conn = get_db()
    cur = conn.cursor(dictionary=True)
    cur.execute("SELECT * FROM sensor_log ORDER BY id DESC LIMIT %s", (n,))
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows

# =========================
# Flask & GPIO 설정
# =========================
app = Flask(__name__)
CORS(app)

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

dht = adafruit_dht.DHT11(board.D23, use_pulseio=False)

latest_temp = None
latest_humid = None
latest_dist = None
led_status = [0, 0, 0]
mode_auto = True

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

    distance = (pulse_end - pulse_start) * 17150
    return round(distance, 2)

def _read_dht(max_retries: int = 3):
    """DHT11 읽기 재시도. 성공 시 (t, h), 실패 시 (None, None) 반환"""
    for _ in range(max_retries):
        try:
            t = dht.temperature
            h = dht.humidity
            if t is not None or h is not None:
                return t, h
        except RuntimeError:
            # 흔한 타이밍/CRC 오류, 잠시 대기 후 재시도
            time.sleep(0.2)
        except Exception as e:
            print("[DHT ERROR]", e)
            break
    return None, None


def sensor_loop():
    """주기적으로 센서 갱신, 주기적 DB 저장"""
    global latest_temp, latest_humid, latest_dist, led_status, mode_auto
    t0 = time.time()
    while True:
        try:
            # 온습도 (재시도 포함), 각각 독립 갱신
            t, h = _read_dht()
            if t is not None:
                latest_temp = t
            if h is not None:
                latest_humid = h

            # 거리
            d = get_distance()
            latest_dist = d

            # Auto 제어
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

            # 3초 주기 DB 저장
            if time.time() - t0 >= 3.0:
                db_insert(latest_temp, latest_humid, latest_dist)
                t0 = time.time()

        except Exception as e:
            print("[ERROR]", e)

        # DHT11 권장 2초 이상 간격
        time.sleep(2.2)

def touch_loop():
    global mode_auto
    prev_touch = GPIO.input(TOUCH_PIN)
    while True:
        curr_touch = GPIO.input(TOUCH_PIN)
        if prev_touch == 1 and curr_touch == 0:
            mode_auto = not mode_auto
            print(f"[INFO] 터치센서 모드 → {'AUTO' if mode_auto else 'MANUAL'}")
        prev_touch = curr_touch
        time.sleep(0.05)

# -------------------- HTML (대시보드) --------------------
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>KU IOT System Controller</title>
<style>
body { font-family: Arial, sans-serif; background:#eef2f3; text-align:center; }
.container { margin:20px auto; padding:20px; width:900px; border:2px solid #2e7d32; border-radius:15px; background:#fff; box-shadow:3px 3px 10px rgba(0,0,0,.2); }
.status { display:flex; justify-content:space-around; margin:20px 0; }
.status div { font-size:18px; }
.grid { display:grid; grid-template-columns:repeat(3,1fr); gap:20px; margin-top:20px; }
.device { border:1px solid #ccc; padding:20px; border-radius:10px; background:#fafafa; }
.on{color:green;font-weight:bold} .off{color:red;font-weight:bold}
.mode-indicator{font-weight:bold; font-size:20px; color:#fff; padding:10px 20px; border-radius:10px; display:inline-block;}
.auto{background:#2e7d32;} .manual{background:#c62828;}
button { padding:10px 16px; margin:4px; border-radius:8px; }
.small { font-size:14px; padding:8px 12px; }
.alert { background:red; color:white; font-weight:bold; padding:10px; margin-top:10px; border-radius:8px; }
</style>
</head>
<body>
<div class="container">
    <h1>KU IOT System Controller</h1>

    <div>
        현재 모드: <span id="mode" class="mode-indicator auto">AUTO</span><br>
        <button onclick="setMode(true)">AUTO</button>
        <button onclick="setMode(false)">MANUAL</button>
    </div>

    <div class="status">
        <div>온도: <span id="temp">--</span> ℃
            <div>
                <button class="small" onclick="location.href='/history/temp'">최근 10개</button>
                <button class="small" onclick="location.href='/history/temp?view=chart'">그래프</button>
            </div>
        </div>
        <div>습도: <span id="humid">--</span> %
            <div>
                <button class="small" onclick="location.href='/history/humid'">최근 10개</button>
                <button class="small" onclick="location.href='/history/humid?view=chart'">그래프</button>
            </div>
        </div>
        <div>거리: <span id="dist">--</span> cm
            <div>
                <button class="small" onclick="location.href='/history/dist'">최근 10개</button>
                <button class="small" onclick="location.href='/history/dist?view=chart'">그래프</button>
            </div>
        </div>
    </div>

    <div id="alert-box"></div>

    <div class="grid">
        <div class="device">
            <h2>에어컨</h2>
            <p id="ac_status" class="off">--</p>
            <button onclick="controlDevice(0,1)">ON</button>
            <button onclick="controlDevice(0,0)">OFF</button>
        </div>
        <div class="device">
            <h2>히터</h2>
            <p id="heater_status" class="off">--</p>
            <button onclick="controlDevice(1,1)">ON</button>
            <button onclick="controlDevice(1,0)">OFF</button>
        </div>
        <div class="device">
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
    const r = await fetch("/status");
    const data = await r.json();
    document.getElementById("temp").innerText  = data.temperature ?? "--";
    document.getElementById("humid").innerText = data.humidity ?? "--";
    document.getElementById("dist").innerText  = data.distance ?? "--";

    const ac = document.getElementById("ac_status");
    ac.innerText = data.led_status[0] ? "ON" : "OFF";
    ac.className = data.led_status[0] ? "on":"off";

    const ht = document.getElementById("heater_status");
    ht.innerText = data.led_status[1] ? "ON" : "OFF";
    ht.className = data.led_status[1] ? "on":"off";

    const dh = document.getElementById("dehum_status");
    dh.innerText = data.led_status[2] ? "ON" : "OFF";
    dh.className = data.led_status[2] ? "on":"off";

    autoMode = data.auto_mode;
    const m = document.getElementById("mode");
    if (autoMode){ m.innerText="AUTO"; m.className="mode-indicator auto"; }
    else { m.innerText="MANUAL"; m.className="mode-indicator manual"; }

    if (data.distance !== null && data.distance <= 10)
         document.getElementById("alert-box").innerHTML = "<div class='alert'>⚠ 침입자 감지! 너무 가까움!</div>";
    else document.getElementById("alert-box").innerHTML = "";
}

async function controlDevice(id, state) {
    if (!autoMode) { await fetch(`/control/${id}/${state}`); fetchData(); }
    else alert("AUTO 모드에서는 수동 제어 불가!");
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

# -------------------- HTML (최근10개/그래프 공용) --------------------
HISTORY_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>{{title}}</title>
<style>
body { font-family: Arial, sans-serif; background:#eef2f3; text-align:center; }
.container { margin:20px auto; padding:20px; width:900px; border:2px solid #1976d2; border-radius:15px; background:#fff; box-shadow:3px 3px 10px rgba(0,0,0,.2); }
table { margin:10px auto; border-collapse:collapse; width:90%; }
th, td { border:1px solid #ccc; padding:8px; }
button { padding:8px 12px; border-radius:8px; }
</style>
</head>
<body>
<div class="container">
  <h2>{{title}}</h2>

  {% if chart %}
    <canvas id="cv" width="800" height="360"></canvas>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script>
      (async ()=>{
        const r = await fetch("{{data_api}}");
        const rows = await r.json();  // 최신→과거
        const labels = rows.map(r=>r.dt).reverse();
        const values = rows.map(r=>Number(r.value)).reverse();
        const ctx = document.getElementById('cv').getContext('2d');
        new Chart(ctx, {
          type:'line',
          data:{ labels, datasets:[{ label:'{{ylabel}}', data: values, fill:false }] },
          options:{ responsive:false }
        });
      })();
    </script>
  {% else %}
    <table>
      <thead><tr><th>시간</th><th>{{ylabel}}</th></tr></thead>
      <tbody id="tb"></tbody>
    </table>
    <script>
      (async ()=>{
        const r = await fetch("{{data_api}}");
        const rows = await r.json();  // 최신→과거
        const tb = document.getElementById('tb');
        rows.forEach(item=>{
          const tr = document.createElement('tr');
          tr.innerHTML = `<td>${item.dt}</td><td>${item.value}</td>`;
          tb.appendChild(tr);
        });
      })();
    </script>
  {% endif %}

  <br>
  <button onclick="location.href='/'">← 대시보드로 돌아가기</button>
</div>
</body>
</html>
"""

# =========================
# 라우트
# =========================
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
    print(f"[INFO] 웹 모드 → {'AUTO' if mode_auto else 'MANUAL'}")
    return ("", 204)

# ---- 최근 10개 JSON (그래프/리스트 공용 API)
@app.route("/history_data/<metric>")
def history_data(metric):
    rows = db_last_n(10)  # id DESC 10개
    out = []
    for r in rows:
        if metric == "temp":
            v = r["temp"]
        elif metric == "humid":
            v = r["humid"]
        else:
            v = r["dist"]
        out.append({"dt": r["dt"].strftime("%Y-%m-%d %H:%M:%S"), "value": v})
    return jsonify(out)

# ---- 페이지 (리스트/그래프)
@app.route("/history/<metric>")
def history(metric):
    view = "chart" if (('chart' in str(getattr(app, 'request_class').args)) or ('chart' in str(getattr(app, 'request_class').environ))) else None
    # 간단 처리: 쿼리스트링 ?view=chart 여부는 Jinja에서 직접 못 보므로 아래처럼 사용
    # Flask 공식 방식으로는 request.args.get('view')가 맞지만, 템플릿 문자열만 쓰는 제약에서 간단화

    ylabel = dict(temp="온도(℃)", humid="습도(%)", dist="거리(cm)")[metric]
    title = f"{ylabel} 최근 10개"
    chart = ("chart" in (app.request_class.environ.get('QUERY_STRING','')))  # 정상 처리
    return render_template_string(
        HISTORY_TEMPLATE,
        title=title,
        ylabel=ylabel,
        data_api=f"/history_data/{metric}",
        chart=chart
    )

# =========================
# 메인
# =========================
if __name__ == "__main__":
    try:
        db_init()
        threading.Thread(target=sensor_loop, daemon=True).start()
        threading.Thread(target=touch_loop, daemon=True).start()
        app.run(host="0.0.0.0", port=8080, debug=False)
    finally:
        GPIO.cleanup()
