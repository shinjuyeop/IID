from flask import Flask, render_template_string, redirect, url_for
import RPi.GPIO as GPIO

app = Flask(__name__)

# === GPIO pin configuration ===
GPIO.setwarnings(False)      # 불필요한 경고 메시지 제거
GPIO.setmode(GPIO.BCM)       # BCM 모드 사용
LED_PINS = [17, 27, 22]      # GPIO 핀: LED1=17, LED2=27, LED3=22

for pin in LED_PINS:
    GPIO.setup(pin, GPIO.OUT, initial=GPIO.LOW)

# Store LED status (0=OFF, 1=ON)
led_status = [0, 0, 0]

# HTML template embedded directly into Python code
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>LED Control</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        .led-box { margin: 20px; padding: 20px; border: 2px solid #333; display: inline-block; width: 200px; }
        .on { color: green; font-weight: bold; }
        .off { color: red; font-weight: bold; }
        button { margin: 10px; padding: 10px 20px; font-size: 16px; }
    </style>
</head>
<body>
    <h1>1번 과제: 3개의 LED 제어 및 상태 모니터링</h1>

    {% for i in range(3) %}
    <div class="led-box">
        <h2>LED {{ i+1 }}</h2>
        <p>Status: 
            {% if led_status[i] == 1 %}
                <span class="on">ON</span>
            {% else %}
                <span class="off">OFF</span>
            {% endif %}
        </p>
        <a href="{{ url_for('control_led', led_id=i, state=1) }}"><button>Turn ON</button></a>
        <a href="{{ url_for('control_led', led_id=i, state=0) }}"><button>Turn OFF</button></a>
    </div>
    {% endfor %}
</body>
</html>
"""

@app.route("/")
def home():
    return redirect(url_for("led_page"))

@app.route("/led")
def led_page():
    return render_template_string(HTML_TEMPLATE, led_status=led_status)

@app.route("/led/<int:led_id>/<int:state>")
def control_led(led_id, state):
    if 0 <= led_id < len(LED_PINS):
        GPIO.output(LED_PINS[led_id], GPIO.HIGH if state == 1 else GPIO.LOW)
        led_status[led_id] = state
    return redirect(url_for("led_page"))

if __name__ == "__main__":
    try:
        app.run(host="0.0.0.0", port=8080, debug=False)
    finally:
        GPIO.cleanup()
