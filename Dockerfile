FROM nginx:latest

MAINTAINER Hleb Rubanau <g.rubanau@gmail.com>

EXPOSE 80 443
VOLUME /etc/letsencrypt /var/lib/letsencrypt
ENV LE_PROD=false

RUN apt-get update && apt-get install -y certbot gettext-base

ADD entrypoint.sh /entrypoint.sh
ADD ssl_params /usr/share/nginx/ssl_params.template
ENTRYPOINT [ '/entrypoint.sh' ]
