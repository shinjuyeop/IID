import RPi.GPIO as GPIO
import time
import board
import adafruit_dht

# 핀 설정
LED_RED = 17
LED_YELLOW = 27
LED_GREEN = 22
TOUCH = 6
TRIG = 20
ECHO = 21

# DHT11 센서 객체 생성 (GPIO23 사용)
# dht = adafruit_dht.DHT11(board.D23, use_pulseio=False)
sensor = adafruit_dht.DHT11
pin = board.D23
dht = sensor(pin)

GPIO.setmode(GPIO.BCM)
GPIO.setup(LED_GREEN, GPIO.OUT)
GPIO.setup(LED_YELLOW, GPIO.OUT)
GPIO.setup(LED_RED, GPIO.OUT)
GPIO.setup(TOUCH, GPIO.IN)
GPIO.setup(TRIG, GPIO.OUT)
GPIO.setup(ECHO, GPIO.IN)

# 초음파 센서 값 출력 함수
def get_distance():
    GPIO.output(TRIG, False)
    time.sleep(0.01)

    GPIO.output(TRIG, True)
    time.sleep(0.00001)
    GPIO.output(TRIG, False)

    while GPIO.input(ECHO) == 0:
        start = time.time()
    while GPIO.input(ECHO) == 1:
        end = time.time()

    duration = end - start
    distance = duration * 17150
    return round(distance, 2)

try:
    system_on = False
    while True:
        if GPIO.input(TOUCH) == GPIO.HIGH: # 터치센서 눌렀을 때
            system_on = not system_on # 눌렀을 때만 시스템 시작 로그를 출력하게끔
            if system_on:
                print("시스템 작동 시작합니다.")
                try:
                    t = dht.temperature
                    h = dht.humidity
                    if t is not None and h is not None:
                        print(f"온도: {t:.1f}도, 습도: {h:.1f}%")
                    else:
                        print("센서 읽기 실패")
                except RuntimeError:
                    # DHT 센서는 읽기 실패가 흔하므로 그냥 무시하고 반복
                    pass

            else:
                print("시스템 작동을 종료합니다.")
                GPIO.output(LED_GREEN, False)
                GPIO.output(LED_YELLOW, False)
                GPIO.output(LED_RED, False)
            time.sleep(1)

        if system_on:
            
            # 거리
            d = get_distance()
            if d > 20:
                print(f"거리는 {d:.1f}cm 입니다. (LED 녹색 ON)")
                GPIO.output(LED_GREEN, True)
                GPIO.output(LED_YELLOW, False)
                GPIO.output(LED_RED, False)
            elif 10 < d <= 20:
                print(f"거리는 {d:.1f}cm 입니다. (LED 노랑색 ON)")
                GPIO.output(LED_GREEN, False)
                GPIO.output(LED_YELLOW, True)
                GPIO.output(LED_RED, False)
            elif 0 < d <= 10:
                print(f"거리는 {d:.1f}cm 입니다. 너무 가깝습니다. (LED 빨간색 ON)")
                GPIO.output(LED_GREEN, False)
                GPIO.output(LED_YELLOW, False)
                GPIO.output(LED_RED, True)

            time.sleep(1)

except KeyboardInterrupt:
    GPIO.cleanup()
