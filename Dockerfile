FROM nginx:latest

MAINTAINER Hleb Rubanau <g.rubanau@gmail.com>


# see https://github.com/moby/moby/issues/19611
CMD ["nginx", "-g", "daemon off;"]
EXPOSE 80 443
VOLUME /etc/letsencrypt /var/lib/letsencrypt
ENV LE_PROD=false

RUN apt-get update && apt-get install -y certbot gettext-base

ADD utils /opt/nginx-le
RUN chmod u+x /opt/nginx-le/*.sh && ln -s /opt/nginx-le/reload_nginx.sh /usr/local/bin/reload_nginx

ADD nginx_params /usr/share/nginx/nginx_params

ENTRYPOINT [ "/opt/nginx-le/entrypoint.sh" ]
