# DISTANCE
import RPi.GPIO as GPIO
import time

TRIG = 20
ECHO = 21

def setup():
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(TRIG, GPIO.OUT)
    GPIO.setup(ECHO, GPIO.IN)

def get_distance():
    # TRIG 핀에 10us 펄스 신호 출력
    GPIO.output(TRIG, True)
    time.sleep(0.00001)  # 10us 펄스
    GPIO.output(TRIG, False)

    # ECHO 핀에서 신호 수신 시간 기록
    start_time = time.time()
    stop_time = time.time()

    # 신호가 HIGH 될 때까지 대기
    while GPIO.input(ECHO) == 0:
        start_time = time.time()

    # 신호가 LOW 될 때까지 대기
    while GPIO.input(ECHO) == 1:
        stop_time = time.time()

    # 시간 차이 계산
    elapsed = stop_time - start_time
    distance = (elapsed * 34300) / 2  # 왕복 시간 → 거리 (cm)
    return distance

def main():
    setup()
    print("START")

    try:
        while True:
            dist = get_distance()
            print(f"{dist:.1f} cm 에 장애물이 있습니다.")
            time.sleep(1)  # 1초마다 측정
    except KeyboardInterrupt:
        pass
    finally:
        GPIO.cleanup()
        print("\n종료")

if __name__ == "__main__":
    main()
