FROM python:3.12-slim

RUN apt-get update && apt-get upgrade -y && apt-get clean

WORKDIR /flaskapp
COPY app.py requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

CMD ["python","app.py"]
