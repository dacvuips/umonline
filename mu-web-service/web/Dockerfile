# Image web nhẹ: chỉ chứa bản web core (vài chục MB) + cấu hình nginx.
# Gói nội dung (/content) và APK (/download) KHÔNG nằm trong image — gắn từ thư mục trên VPS (xem stack.yml),
# nên cập nhật nội dung không cần build lại image.
FROM nginx:1.27-alpine
RUN rm -rf /etc/nginx/conf.d/* /usr/share/nginx/html/*
COPY web/nginx.conf /etc/nginx/conf.d/default.conf
COPY dist/web/ /usr/share/nginx/html/
COPY web/kill-sw.js /usr/share/nginx/html/index.service.worker.js
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1/healthz >/dev/null || exit 1
EXPOSE 80
