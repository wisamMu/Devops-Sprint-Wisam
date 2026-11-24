FROM nginxinc/nginx-unprivileged:1.31.7-alpine
USER root
RUN apk upgrade --no-cache \
&& sed -i 's/8080/7777/g' /etc/nginx/conf.d/default.conf
USER nginx
COPY --chown=nginx:nginx index.html health.html /usr/share/nginx/html/
EXPOSE 7777
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
CMD wget -qO- http://127.0.0.1:7777/health.html || exit 1
