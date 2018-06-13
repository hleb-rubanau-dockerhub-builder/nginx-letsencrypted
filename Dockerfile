FROM nginx:latest

MAINTAINER Hleb Rubanau <g.rubanau@gmail.com>

RUN apt-get update && apt-get install -y certbot gettext-base supervisor curl

# see https://github.com/moby/moby/issues/19611
# CMD ["nginx", "-g" , "\"daemon off;\""]

EXPOSE 80 443
VOLUME /mnt/data

ARG LOGLEVEL=warn
RUN sed -i -r -e '/^logfile=/anodaemon=true' \
              -e "/^logfile=/aloglevel=$LOGLEVEL" \
              -e 's|^logfile=.*|logfile=/dev/null|' \
                    /etc/supervisor/supervisord.conf

RUN mkdir -p /mnt/data/letsencrypt \
    && mkdir -p /etc/nginx/ssl && mv /etc/nginx/ssl /mnt/data/nginx_ssl && ln -s /mnt/data/nginx_ssl /etc/nginx/ssl \
    && mkdir -p /etc/letsencrypt && mv /etc/letsencrypt /mnt/data/letsencrypt/etc \
        && ln -s /mnt/data/letsencrypt/etc /etc/letsencrypt \
    && mkdir -p /var/lib/letsencrypt && mv /var/lib/letsencrypt /mnt/data/letsencrypt/lib \ 
        && ln -s /mnt/data/letsencrypt/lib /var/lib/letsencrypt \
    && mkdir -p /var/log/letsencrypt && mv /var/log/letsencrypt /mnt/data/letsencrypt/logs  \
        && ln -s /mnt/data/letsencrypt/logs /var/log/letsencrypt    \
    && mkdir -p /var/log/watchers \
        && mkdir -p /var/log/watchers/supervisor_logs \
        && mv /var/log/watchers /mnt/data/watchers \
        && ln -s /mnt/data/watchers /var/log/watchers 

#RUN mkfifo /dev/docker_stderr

ENV CERT_MODE=staging AUTOFILL_DOMAINS=false \
    CERTBOT_WEBROOT=/var/lib/letsencrypt/challenges                 \
    LETSENCRYPT_FAILURE_LOG_FILE=/var/log/letsencrypt/failure.log   \
    LETSENCRYPT_FAILURE_GRACE_PERIOD=20      \
    SSL_TRY_TO_FAILOVER_ON_ERRORS=true        \
    WATCHERS_STATE_DIR=/var/log/watchers     \
    CERTS_UPDATER_LOG=/var/log/watchers/certs_updater.log   \
    NGINX_CONF_WATCHER_LOG=/var/run/nginx_conf_watcher.log          

ENV SNAKEOIL_COMPANY_NAME=SPECTRE SNAKEOIL_COMPANY_CITY=London SNAKEOIL_COMPANY_COUNTRY=UK \
    SNAKEOIL_COMPANY_DEPT="Self-signed certificates unit"

COPY metrics_collection.conf /etc/nginx/metrics_collection.conf 

RUN sed -i -e '/conf.d/i       ssl_dhparam /etc/nginx/ssl/dhparam.pem ; ' \
           -e '/conf.d/i       include  /etc/nginx/metrics_collection.conf ; ' \
           /etc/nginx/nginx.conf 

ADD utils /usr/local/bin 
RUN chmod u+x /usr/local/bin/* /usr/local/bin/supervisord/* \
    && mv /usr/local/bin/helper_functions.sh /usr/local/share/helper_functions.sh 

# backwards-compatibility with earlier versions
RUN ln -s /usr/local/bin/reload_nginx.sh /usr/local/bin/reload_nginx \
    && ln -s /usr/local/bin/ /opt/nginx-le 

COPY nginx_params /usr/share/nginx/nginx_params

COPY supervisord.conf /etc/supervisor/conf.d

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
CMD [ "/usr/local/bin/bootstrap.sh" ]
