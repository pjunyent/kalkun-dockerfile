#(c) pjunyent, EUPL v.1.2
#syntax=docker/dockerfile:1

FROM dockage/alpine:3.19-openrc

ARG dbuser=kalkun
ARG dbpass=kalkun
ARG dbname=kalkun
ARG dbhostname=127.0.0.1

ENV TZ=Etc/UTC

#########################################
# Nginx Alpine Slim 3.19 official docker code
#########################################
LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"

ENV NGINX_VERSION 1.25.5
ENV PKG_RELEASE   1

RUN set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup -g 101 -S nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
    && apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-r${PKG_RELEASE} \
    " \
# install prerequisites for public key and pkg-oss checks
    && apk add --no-cache --virtual .checksum-deps \
        openssl \
    && case "$apkArch" in \
        x86_64|aarch64) \
# arches officially built by upstream
            set -x \
            && KEY_SHA512="e09fa32f0a0eab2b879ccbbc4d0e4fb9751486eedda75e35fac65802cc9faa266425edf83e261137a2f4d16281ce2c1a5f4502930fe75154723da014214f0655" \
            && wget -O /tmp/nginx_signing.rsa.pub https://nginx.org/keys/nginx_signing.rsa.pub \
            && if echo "$KEY_SHA512 */tmp/nginx_signing.rsa.pub" | sha512sum -c -; then \
                echo "key verification succeeded!"; \
                mv /tmp/nginx_signing.rsa.pub /etc/apk/keys/; \
            else \
                echo "key verification failed!"; \
                exit 1; \
            fi \
            && apk add -X "https://nginx.org/packages/mainline/alpine/v$(egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release)/main" --no-cache $nginxPackages \
            ;; \
        *) \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published packaging sources
            set -x \
            && tempDir="$(mktemp -d)" \
            && chown nobody:nobody $tempDir \
            && apk add --no-cache --virtual .build-deps \
                gcc \
                libc-dev \
                make \
                openssl-dev \
                pcre2-dev \
                zlib-dev \
                linux-headers \
                bash \
                alpine-sdk \
                findutils \
            && su nobody -s /bin/sh -c " \
                export HOME=${tempDir} \
                && cd ${tempDir} \
                && curl -f -O https://hg.nginx.org/pkg-oss/archive/93ac6e194ad0.tar.gz \
                && PKGOSSCHECKSUM=\"d56d10fbc6a1774e0a000b4322c5f847f8dfdcc3035b21cfd2a4a417ecce46939f39ff39ab865689b60cf6486c3da132aa5a88fa56edaad13d90715affe2daf0 *93ac6e194ad0.tar.gz\" \
                && if [ \"\$(openssl sha512 -r 93ac6e194ad0.tar.gz)\" = \"\$PKGOSSCHECKSUM\" ]; then \
                    echo \"pkg-oss tarball checksum verification succeeded!\"; \
                else \
                    echo \"pkg-oss tarball checksum verification failed!\"; \
                    exit 1; \
                fi \
                && tar xzvf 93ac6e194ad0.tar.gz \
                && cd pkg-oss-93ac6e194ad0 \
                && cd alpine \
                && make base \
                && apk index -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
                && abuild-sign -k ${tempDir}/.abuild/abuild-key.rsa ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz \
                " \
            && cp ${tempDir}/.abuild/abuild-key.rsa.pub /etc/apk/keys/ \
            && apk del --no-network .build-deps \
            && apk add -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
            ;; \
    esac \
# remove checksum deps
    && apk del --no-network .checksum-deps \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then rm -rf "$tempDir"; fi \
    && if [ -f "/etc/apk/keys/abuild-key.rsa.pub" ]; then rm -f /etc/apk/keys/abuild-key.rsa.pub; fi \
# Bring in gettext so we can get `envsubst`, then throw
# the rest away. To do this, we need to install `gettext`
# then move `envsubst` out of the way so `gettext` can
# be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache $runDeps \
    && apk del --no-network .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
# Bring in tzdata so users could set the timezones through the environment
# variables
    && apk add --no-cache tzdata \
# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
# create a docker-entrypoint.d directory
    && mkdir /docker-entrypoint.d

RUN /bin/busybox wget -q https://raw.githubusercontent.com/nginxinc/docker-nginx/3fb7e2e6266d5652dabe275dbfd50bdb3418361e/mainline/alpine-slim/docker-entrypoint.sh -O /docker-entrypoint.sh
RUN /bin/busybox wget -q https://raw.githubusercontent.com/nginxinc/docker-nginx/3fb7e2e6266d5652dabe275dbfd50bdb3418361e/mainline/alpine-slim/10-listen-on-ipv6-by-default.sh -O  /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
RUN /bin/busybox wget -q https://raw.githubusercontent.com/nginxinc/docker-nginx/3fb7e2e6266d5652dabe275dbfd50bdb3418361e/mainline/alpine-slim/15-local-resolvers.envsh -O  /docker-entrypoint.d/15-local-resolvers.envsh
RUN /bin/busybox wget -q https://raw.githubusercontent.com/nginxinc/docker-nginx/3fb7e2e6266d5652dabe275dbfd50bdb3418361e/mainline/alpine-slim/20-envsubst-on-templates.sh -O  /docker-entrypoint.d/20-envsubst-on-templates.sh
RUN /bin/busybox wget -q https://raw.githubusercontent.com/nginxinc/docker-nginx/3fb7e2e6266d5652dabe275dbfd50bdb3418361e/mainline/alpine-slim/30-tune-worker-processes.sh -O  /docker-entrypoint.d/30-tune-worker-processes.sh
RUN /bin/busybox chmod ugo+x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80

STOPSIGNAL SIGQUIT
#########################################
#########################################

RUN su
#Install gammu-smsd, PHP 8.1 & mariadb-client
RUN /sbin/apk update && /sbin/apk add --no-cache --no-scripts \
    dbus

RUN /sbin/apk update && /sbin/apk add --no-cache \
    gammu gammu-smsd gammu-dev \
    php82 php82-ctype php82-curl php82-fpm php82-intl php82-ldap php82-mbstring php82-session php82-mysqli php82-xml composer mariadb-client tzdata \
    cronie cronie-openrc logrotate

#Config Gammu-smsd Openrc init script
COPY ./config/openrc-gammu-smsd /etc/init.d/gammu-smsd

#Configure OpenRC & install kalkun
RUN /bin/busybox mkdir -p /run/openrc /var/www /var/log/gammu /opt/config \
  && /bin/busybox touch /run/openrc/softlevel

# Download kalkun
RUN /bin/busybox wget -q https://github.com/kalkun-sms/Kalkun/releases/download/v0.8.2.1/Kalkun_v0.8.2.1_forPHP8.2.tar.xz -O kalkun.tar.xz \
  && /bin/busybox tar -Jxf kalkun.tar.xz -C /var/www --strip-components=1 \
  && /bin/busybox rm kalkun.tar.xz \
# Make user www
  && /bin/busybox adduser -D -g 'www' www \
  && /bin/busybox sed -i "s|user\s*=\s*nobody|user = www|g" /etc/php82/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|;listen.owner\s*=\s*nobody|listen.owner = www|g" /etc/php82/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|;listen.mode\s*=\s*0660|listen.mode = 0660|g" /etc/php82/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|;listen.group\s*=\s*nobody|listen.group = www|g" /etc/php82/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|group\s*=\s*nobody|group = www|g" /etc/php82/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|;chdir\s*=\s/var/www|chdir = /var/www|g" /etc/php82/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|;log_level\s*=\s*notice|log_level = notice|g" /etc/php82/php-fpm.conf \
  \
  && cd /var/www/ \
  && composer install --no-dev

# Copy configs and symlink
COPY ./config/nginx.conf /opt/config/nginx.conf
COPY ./config/gammu-smsdrc /opt/config/gammurc
RUN  /bin/busybox ln -s /opt/config/gammurc /etc/gammurc \
  && /bin/busybox rm /etc/nginx/nginx.conf \
  && /bin/busybox ln -s /opt/config/nginx.conf /etc/nginx/nginx.conf

# Set database mode in config.php & encription key
RUN /bin/busybox sed -i "s|\$config\[\'sess_driver\'\] = \'files\';|\/\/\$config\[\'sess_driver\'\] = \'files\';|" /var/www/application/config/config.php \
  && /bin/busybox sed -i "s|\$config\[\'sess_save_path\'\] = NULL;|\/\/\$config\[\'sess_save_path\'] = NULL;|g" /var/www/application/config/config.php \
  && /bin/busybox sed -i "s|\/\/\$config\[\'sess_driver\'\] = \'database\';|\$config\[\'sess_driver\'\] = \'database\';|g" /var/www/application/config/config.php \
  && /bin/busybox sed -i "s|\/\/\$config\[\'sess_save_path\'\] = \'ci_sessions\';|\$config\[\'sess_save_path\'\] = \'ci_sessions\';|g" /var/www/application/config/config.php \
  && encription=$(/usr/bin/php -r 'echo bin2hex(random_bytes(16)), "\n";') \
  && /bin/busybox sed -i "s|F0af18413d1c9e03A6d8d1273160f5Ed|$encription|g" /var/www/application/config/config.php

# Change kalkun_settings.php to disable append_username & set max sms per minute to 0.5/min
RUN /bin/busybox sed -i "s|\$config\[\'append_username\'\] = TRUE;|\$config\[\'append_username\'\] = FALSE;|g" /var/www/application/config/kalkun_settings.php \
  && /bin/busybox sed -i "s|\$config\[\'max_sms_sent_by_minute\'\] = 0;|\$config\[\'max_sms_sent_by_minute\'\] = 0.5;|g" /var/www/application/config/kalkun_settings.php 

# Set scripts path in daemon.php, daemon.sh & outbox_queue.sh
RUN /bin/busybox sed -i "s|http\:\/\/localhost\/kalkun|http\:\/\/localhost|g" /var/www/scripts/daemon.php \
  && /bin/busybox sed -i "s|path\/to\/kalkun|var\/www|g" /var/www/scripts/daemon.sh \
  && /bin/busybox sed -i "s|path\/to\/kalkun|var\/www|g" /var/www/scripts/outbox_queue.sh

# Configure database connection in database.php
RUN /bin/busybox sed -i "s|\'username\' => \'root\'|\'username\' => \'${dbuser}\'|g" /var/www/application/config/database.php \
  && /bin/busybox sed -i "s|\'password\' => \'password\'|\'password\' => \'${dbpass}\'|g" /var/www/application/config/database.php \
  && /bin/busybox sed -i "s|\'database\' => \'kalkun\'|\'database\' => \'${dbname}\'|g" /var/www/application/config/database.php \
  && /bin/busybox sed -i "s|\'hostname\' => \'127.0.0.1\'|\'hostname\' => \'${dbhostname}\'|g" /var/www/application/config/database.php

# Delete install file
RUN /bin/busybox rm /var/www/install

# Fix kalkun 0.8.0-rc1 kalkun_helper.php is_phone_number_valid() error
# RUN /bin/busybox sed -i "s|tr(\'Please specify a valid mobile phone number\')|TRUE|g" /var/www/application/helpers/kalkun_helper.php \
#  && /bin/busybox sed -i "s|\$e->getMessage()|TRUE|g" /var/www/application/helpers/kalkun_helper.php

# Fix CodeIgniter 3 for Kalkun 0.8.2 adding PHP 8.2 support via pull https://github.com/bcit-ci/CodeIgniter/pull/6173
RUN /bin/busybox rm /var/www/vendor/codeigniter/framework/system/core/Controller.php \
  && /bin/busybox rm /var/www/vendor/codeigniter/framework/system/core/Loader.php \
  && /bin/busybox rm /var/www/vendor/codeigniter/framework/system/core/Router.php \
  && /bin/busybox rm /var/www/vendor/codeigniter/framework/system/core/URI.php \
  && /bin/busybox rm /var/www/vendor/codeigniter/framework/system/database/DB_driver.php \
  && /bin/busybox rm /var/www/vendor/codeigniter/framework/system/database/drivers/postgre/postgre_forge.php \
  && /bin/busybox rm /var/www/vendor/codeigniter/framework/system/libraries/Driver.php \
  && /bin/busybox rm /var/www/vendor/codeigniter/framework/system/libraries/Image_lib.php \
  && /bin/busybox rm /var/www/vendor/codeigniter/framework/system/libraries/Table.php

RUN /bin/busybox wget -q https://raw.githubusercontent.com/ib3ltd/CodeIgniter/master/system/core/Controller.php -O /var/www/vendor/codeigniter/framework/system/core/Controller.php \
  && /bin/busybox wget -q https://raw.githubusercontent.com/ib3ltd/CodeIgniter/master/system/core/Loader.php -O /var/www/vendor/codeigniter/framework/system/core/Loader.php \
  && /bin/busybox wget -q https://raw.githubusercontent.com/ib3ltd/CodeIgniter/master/system/core/Router.php -O /var/www/vendor/codeigniter/framework/system/core/Router.php \
  && /bin/busybox wget -q https://raw.githubusercontent.com/ib3ltd/CodeIgniter/master/system/core/URI.php -O /var/www/vendor/codeigniter/framework/system/core/URI.php \
  && /bin/busybox wget -q https://raw.githubusercontent.com/ib3ltd/CodeIgniter/master/system/database/DB_driver.php -O /var/www/vendor/codeigniter/framework/system/database/DB_driver.php \
  && /bin/busybox wget -q https://raw.githubusercontent.com/ib3ltd/CodeIgniter/master/system/database/drivers/postgre/postgre_forge.php -O /var/www/vendor/codeigniter/framework/system/database/drivers/postgre/postgre_forge.php \
  && /bin/busybox wget -q https://raw.githubusercontent.com/ib3ltd/CodeIgniter/master/system/libraries/Driver.php -O /var/www/vendor/codeigniter/framework/system/libraries/Driver.php \
  && /bin/busybox wget -q https://raw.githubusercontent.com/ib3ltd/CodeIgniter/master/system/libraries/Image_lib.php -O /var/www/vendor/codeigniter/framework/system/libraries/Image_lib.php \
  && /bin/busybox wget -q https://raw.githubusercontent.com/ib3ltd/CodeIgniter/master/system/libraries/Table.php -O /var/www/vendor/codeigniter/framework/system/libraries/Table.php

# Set permissions
RUN /bin/busybox chown -R www:www /var/www \
  && /bin/busybox chown -R www:www /usr/share/nginx \
  && /bin/busybox chmod +x /etc/init.d/gammu-smsd \
  && /bin/busybox chmod +x /var/www/scripts/daemon.sh /var/www/scripts/daemon.php \
  && /bin/busybox chmod +x /var/www/scripts/outbox_queue.sh /var/www/scripts/outbox_queue.php \
  # Create autostart
  && rc-update add gammu-smsd default \
  && rc-update add php-fpm82 default \
  && rc-update add nginx default \
  && rc-update add cronie default

RUN /bin/busybox chmod +x /etc/init.d/gammu-smsd && /sbin/rc-update add gammu-smsd default \
  # Remove hostname & networking error
  && rm /etc/init.d/hostname && rm /etc/init.d/networking


RUN /bin/busybox chmod ugo+x /sbin/init
VOLUME /opt/config
CMD ["/sbin/init"]
