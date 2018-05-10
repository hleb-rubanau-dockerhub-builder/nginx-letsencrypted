FROM nginx:latest

MAINTAINER Hleb Rubanau <g.rubanau@gmail.com>

RUN apt-get update && apt-get install -y certbot gettext-base supervisor

# see https://github.com/moby/moby/issues/19611
# CMD ["nginx", "-g" , "\"daemon off;\""]

EXPOSE 80 443
VOLUME /mnt/data
RUN mkdir -p /mnt/data/letsencrypt \
    && mkdir -p /etc/nginx/ssl && mv /etc/nginx/ssl /mnt/data/nginx_ssl && ln -s /mnt/data/nginx_ssl /etc/nginx/ssl \
    && mkdir -p /etc/letsencrypt && mv /etc/letsencrypt /mnt/data/letsencrypt/etc \
        && ln -s /mnt/data/letsencrypt/etc /etc/letsencrypt \
    && mkdir -p /var/lib/letsencrypt && mv /var/lib/letsencrypt /mnt/data/letsencrypt/lib \ 
        && ln -s /mnt/data/letsencrypt/lib /var/lib/letsencrypt \
    && mkdir -p /var/log/letsencrypt && mv /var/log/letsencrypt /mnt/data/letsencrypt/logs  \
        && ln -s /mnt/data/letsencrypt/logs /var/log/letsencrypt

ENV CERT_MODE=staging AUTOFILL_DOMAINS=false \
    LETSENCRYPT_FAILURE_LOG_FILE=/var/log/letsencrypt/failure.log   \
    LETSENCRYPT_FAILURE_GRACE_PERIOD=20      \
    LETSENCRYPT_FAILOVER_TO_SNAKEOIL=yes

ENV SNAKEOIL_COMPANY_NAME=SPECTRE SNAKEOIL_COMPANY_CITY=London SNAKEOIL_COMPANY_COUNTRY=UK \
    SNAKEOIL_COMPANY_DEPT="Self-signed certificates unit"

RUN sed -i -e '/conf.d/i       ssl_dhparam /etc/nginx/ssl/dhparam.pem ; '  /etc/nginx/nginx.conf

ADD utils /usr/local/bin 
RUN chmod u+x /usr/local/bin/*.sh 
# backwards-compatibility with earlier versions
RUN ln -s /usr/local/bin/reload_nginx.sh ./reload_nginx \
    && ln -s /usr/local/bin/ /opt/nginx-le 

ADD nginx_params /usr/share/nginx/nginx_params

ENTRYPOINT [ "/opt/nginx-le/entrypoint.sh" ]
