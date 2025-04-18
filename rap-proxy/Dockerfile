FROM python:3.10-slim
WORKDIR /app
COPY rap_proxy.py .
RUN pip install fastapi uvicorn kubernetes httpx
ENV PYTHONUNBUFFERED=1
CMD ["uvicorn", "rap_proxy:app", "--host", "0.0.0.0", "--port", "80"]
