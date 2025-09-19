# TOUCH
import RPi.GPIO as GPIO
import time

TOUCH = 6  # 터치 센서 OUT 핀 연결 (BCM 번호 기준)

def main():
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(TOUCH, GPIO.IN)

    print("터치 센서 감지 시작 (Ctrl+C 종료)")

    try:
        while True:
            if GPIO.input(TOUCH) == GPIO.HIGH:
                print("TOUCH")
            else:
                print("RELEASED")
            time.sleep(0.5)  # 0.5초마다 상태 출력
    except KeyboardInterrupt:
        pass
    finally:
        GPIO.cleanup()
        print("\nGPIO 정리 완료, 종료")

if __name__ == "__main__":
    main()
