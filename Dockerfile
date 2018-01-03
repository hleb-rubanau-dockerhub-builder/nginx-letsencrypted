FROM nginx:latest

MAINTAINER Hleb Rubanau <g.rubanau@gmail.com>

EXPOSE 80 443
VOLUME /etc/letsencrypt /var/lib/letsencrypt
ENV LE_PROD=false

RUN apt-get update && apt-get install -y certbot gettext-base

ADD utils /opt/nginx-le
RUN chmod u+x /opt/nginx-le/*.sh

ADD ssl_params /usr/share/nginx/ssl_params.template

ENTRYPOINT [ '/opt/nginx-le/entrypoint.sh' ]
