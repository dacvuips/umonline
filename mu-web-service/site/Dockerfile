FROM python:3.12-alpine
WORKDIR /app
RUN pip install --no-cache-dir pg8000==1.31.2 bcrypt==4.2.1
COPY website/ /app/
RUN mkdir -p /app/data && adduser -D -u 10001 mu && chown -R mu /app/data
USER mu
EXPOSE 8000
CMD ["python", "-u", "server.py", "--host", "0.0.0.0", "--port", "8000"]
