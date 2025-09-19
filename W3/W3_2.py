from flask import Flask, render_template_string, url_for
import RPi.GPIO as GPIO

app = Flask(__name__)

# === GPIO pin configuration ===
GPIO.setwarnings(False)      # 경고 메시지 제거
GPIO.setmode(GPIO.BCM)       # BCM 모드 사용
TOUCH_PIN = 6               # Example: GPIO24
GPIO.setup(TOUCH_PIN, GPIO.IN)

# Store latest touch status (0 = released, 1 = pressed)
touch_status = 0

# Embedded HTML template
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Touch Sensor Monitor</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        .status-box { margin: 20px; padding: 20px; border: 2px solid #333; display: inline-block; width: 300px; }
        .pressed { color: green; font-weight: bold; font-size: 20px; }
        .released { color: red; font-weight: bold; font-size: 20px; }
        button { margin-top: 20px; padding: 10px 20px; font-size: 16px; }
    </style>
</head>
<body>
    <h1>2번 과제: 터치 센서 상태 모니터링</h1>

    <div class="status-box">
        <h2>Sensor Status</h2>
        {% if touch_status == 1 %}
            <p class="pressed">Touched! (PRESSED)</p>
        {% else %}
            <p class="released">Untouched! (RELEASED)</p>
        {% endif %}
    </div>

    <br>
    <a href="{{ url_for('touch_page') }}"><button>Refresh Status</button></a>
</body>
</html>
"""

@app.route("/")
def home():
    global touch_status
    touch_status = GPIO.input(TOUCH_PIN)
    return render_template_string(HTML_TEMPLATE, touch_status=touch_status)

@app.route("/touch")
def touch_page():
    global touch_status
    # Read the current sensor value
    touch_status = GPIO.input(TOUCH_PIN)
    return render_template_string(HTML_TEMPLATE, touch_status=touch_status)

if __name__ == "__main__":
    try:
        # debug=False → 자동 재실행 방지
        app.run(host="0.0.0.0", port=8080, debug=False)
    finally:
        GPIO.cleanup()
