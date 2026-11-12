FROM python:3.12-alpine
RUN pip install --no-cache-dir "websockets>=13,<16" pg8000==1.31.2 bcrypt==4.2.1
WORKDIR /app
COPY gateway/ws_proxy.py gateway/presence.py gateway/auth.py ./
USER nobody
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import socket;socket.create_connection(('127.0.0.1',8080),2).close()" || exit 1
CMD ["python", "-u", "ws_proxy.py"]
