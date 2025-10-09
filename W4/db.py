import mariadb

db = mariadb.connect(
    user="shin",
    password="shin",
    host="localhost",
    port=3306,
    database="IOT"
)

cur = db.cursor()

cur.execute("select * from students")

while True:
    status = cur.fetchone()
    if not status: break
    print(status)

cur.close()
db.close()
