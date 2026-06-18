FROM mcr.microsoft.com/devcontainers/python:3.13-bookworm

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8088
CMD ["python", "main.py"]
