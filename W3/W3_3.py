from flask import Flask, render_template_string
import RPi.GPIO as GPIO
import time

app = Flask(__name__)

# === GPIO 핀 설정 (초음파 센서) ===
TRIG = 20
ECHO = 21

GPIO.setmode(GPIO.BCM)
GPIO.setup(TRIG, GPIO.OUT)
GPIO.setup(ECHO, GPIO.IN)

def get_distance():
    """초음파 센서를 이용해 거리(cm) 측정"""
    # Trigger 핀 LOW
    GPIO.output(TRIG, False)
    time.sleep(0.0002)

    # Trigger 핀 HIGH (10us)
    GPIO.output(TRIG, True)
    time.sleep(0.00001)
    GPIO.output(TRIG, False)

    # Echo 핀 HIGH 시작
    pulse_start = time.time()
    timeout = pulse_start + 0.04  # 40ms timeout
    while GPIO.input(ECHO) == 0 and time.time() < timeout:
        pulse_start = time.time()

    # Echo 핀 HIGH 끝
    pulse_end = time.time()
    timeout = pulse_end + 0.04
    while GPIO.input(ECHO) == 1 and time.time() < timeout:
        pulse_end = time.time()

    # 펄스 길이 계산
    pulse_duration = pulse_end - pulse_start
    distance = pulse_duration * 17150  # cm 단위로 변환
    return round(distance, 2)

# === HTML 템플릿 ===
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Ultrasonic Sensor Monitor</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        .status-box { margin: 20px; padding: 20px; border: 2px solid #333; display: inline-block; width: 300px; }
        .safe { color: green; font-weight: bold; font-size: 20px; }
        .alert { color: red; font-weight: bold; font-size: 20px; }
        button { margin-top: 20px; padding: 10px 20px; font-size: 16px; }
    </style>
</head>
<body>
    <h1>3번 과제: 초음파 센서 거리 측정</h1>

    <div class="status-box">
        <h2>Distance</h2>
        {% if distance is not none %}
            <p>{{ distance }} cm</p>
            {% if alert %}
                <p class="alert">⚠ 너무 가까움! (ALERT)</p>
            {% else %}
                <p class="safe">✅ 안전 거리 (SAFE)</p>
            {% endif %}
        {% else %}
            <p class="alert">Sensor Error</p>
        {% endif %}
    </div>

    <br>
    <a href="{{ url_for('distance_page') }}"><button>Check Distance</button></a>
</body>
</html>
"""

@app.route("/")
def home():
    # 초기 페이지 (측정 전 상태)
    return render_template_string(HTML_TEMPLATE, distance=None, alert=False)

@app.route("/distance")
def distance_page():
    try:
        dist = get_distance()
        alert = dist <= 10.0  # 10cm 이하일 때 경고
        return render_template_string(HTML_TEMPLATE, distance=dist, alert=alert)
    except Exception:
        return render_template_string(HTML_TEMPLATE, distance=None, alert=False)

if __name__ == "__main__":
    try:
        app.run(host="0.0.0.0", port=8080, debug=True)
    finally:
        GPIO.cleanup()
