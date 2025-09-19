# LED
import RPi.GPIO as GPIO
import time
LED = 23

GPIO.setmode(GPIO.BCM)
GPIO.setup(LED, GPIO.OUT, initial=GPIO.LOW)
try:
    while True:
        GPIO.output(LED, GPIO.HIGH)
        print("LED On")
        time.sleep(1)
        GPIO.output(LED, GPIO.LOW)
        print("LED Off")
        time.sleep(1)
except KeyboardInterrupt:
    print("\n Program Terminated")

finally:
    GPIO.cleanup()
