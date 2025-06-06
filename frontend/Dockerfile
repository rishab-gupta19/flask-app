FROM nginx:alpine
RUN apk add --no-cache gettext

COPY nginx/default.conf.template /etc/nginx/conf.d/default.conf.template

COPY . /usr/share/nginx/html

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["nginx", "-g", "daemon off;"]
