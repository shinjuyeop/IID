# BUTTON
import RPi.GPIO as GPIO
import time

LED = 17
BUTTON = 18  

def main():
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(LED, GPIO.OUT, initial=GPIO.LOW)
    GPIO.setup(BUTTON, GPIO.IN, pull_up_down=GPIO.PUD_UP)

    print("START")

    try:
        while True:
            if GPIO.input(BUTTON) == GPIO.LOW:   # PUSH
                GPIO.output(LED, GPIO.HIGH)   # LED ON
                print("PUSH")
            else:
                GPIO.output(LED, GPIO.LOW)    # LED OFF
                print("RELEASED")

            time.sleep(0.1)  # Delay

    except KeyboardInterrupt:
        pass
    finally:
        GPIO.output(LED, GPIO.LOW)
        GPIO.cleanup()
        print("\nSTOP")

if __name__ == "__main__":
    main()