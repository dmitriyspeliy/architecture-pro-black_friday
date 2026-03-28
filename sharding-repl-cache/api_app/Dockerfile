FROM python:3.12.1-slim

WORKDIR /app
EXPOSE 8080

COPY requirements.txt ./

RUN python -m pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir --default-timeout=120 \
    --trusted-host pypi.org \
    --trusted-host files.pythonhosted.org \
    -i https://pypi.org/simple \
    -r requirements.txt

COPY app.py /app/

ENTRYPOINT ["uvicorn"]
CMD ["app:app", "--host", "0.0.0.0", "--port", "8080"]