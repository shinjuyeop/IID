# DHT11
import adafruit_dht
import time
import board

sensor = adafruit_dht.DHT11
pin = board.D23
dht = sensor(pin)

print("Reading DHT... Ctrl+C Stops")

try:
    while(True):
        try:
            t = dht.temperature
            h = dht.humidity
            if t is not None and h is not None:
                print(f"Temp={t:.1f}C Humidity={h:.1f}%")
            else:
                print("Can't read Sensor Data")
        except RuntimeError:
            pass
        time.sleep(2)

except KeyboardInterrupt:
    print("\n Terminating...")
finally:
    dht.exit()
