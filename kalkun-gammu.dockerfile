#(c) pjunyent, EUPL v.1.2
#syntax=docker/dockerfile:1
FROM nginx:stable-alpine
ARG dbuser=kalkun
ARG dbpass=kalkun
ARG dbname=kalkun
ARG dbhostname=127.0.0.1

ENV TZ=Etc/UTC

#Install gammu-smsd, PHP 8.1, mariadb-client & openrc
RUN /sbin/apk update && /sbin/apk add --no-cache gammu gammu-smsd gammu-dev\
    php8 php8-ctype php8-curl php8-fpm php8-intl php8-ldap php8-mbstring php8-session php8-mysqli composer mariadb-client tzdata\
    openrc

#Config openrc
COPY ./config/openrc-gammu-smsd /etc/init.d/gammu-smsd

#Configure OpenRC & instal kalkun
RUN /bin/busybox mkdir -p /run/openrc /var/www /var/log/gammu /opt/config\
  && /bin/busybox touch /run/openrc/softlevel \
  # Download kalkun
  && /bin/busybox wget -q https://github.com/kalkun-sms/Kalkun/releases/download/v0.8.0-rc-1/Kalkun_v0.8.0-rc-1_forPHP8.0.tar.xz -O kalkun.tar.xz \
  && /bin/busybox tar -Jxvf kalkun.tar.xz -C /var/www --strip-components=1 \
  && /bin/busybox rm kalkun.tar.xz \
  # Make user www
  && /bin/busybox adduser -D -g 'www' www \
  && /bin/busybox sed -i "s|user\s*=\s*nobody|user = www|g" /etc/php8/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|;listen.owner\s*=\s*nobody|listen.owner = www|g" /etc/php8/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|;listen.mode\s*=\s*0660|listen.mode = 0660|g" /etc/php8/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|;listen.group\s*=\s*nobody|listen.group = www|g" /etc/php8/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|group\s*=\s*nobody|group = www|g" /etc/php8/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|;chdir\s*=\s/var/www|chdir = /var/www|g" /etc/php8/php-fpm.d/www.conf \
  && /bin/busybox sed -i "s|;log_level\s*=\s*notice|log_level = notice|g" /etc/php8/php-fpm.conf \
  \
  && cd /var/www/ \
  && composer install --no-dev

#Copy configs and symlink
COPY ./config/nginx.conf /opt/config/nginx.conf
COPY ./config/gammu-smsdrc /opt/config/gammurc
RUN  /bin/busybox ln -s /opt/config/gammurc /etc/gammurc \
  && /bin/busybox rm /etc/nginx/nginx.conf \
  && /bin/busybox ln -s /opt/config/nginx.conf /etc/nginx/nginx.conf

#Set database mode in config.php & encription key
RUN /bin/busybox sed -i "s|\$config\[\'sess_driver\'\] = \'files\';|\/\/\$config\[\'sess_driver\'\] = \'files\';|" /var/www/application/config/config.php \
  && /bin/busybox sed -i "s|\$config\[\'sess_save_path\'\] = NULL;|\/\/\$config\[\'sess_save_path\'] = NULL;|g" /var/www/application/config/config.php \
  && /bin/busybox sed -i "s|\/\/\$config\[\'sess_driver\'\] = \'database\';|\$config\[\'sess_driver\'\] = \'database\';|g" /var/www/application/config/config.php \
  && /bin/busybox sed -i "s|\/\/\$config\[\'sess_save_path\'\] = \'ci_sessions\';|\$config\[\'sess_save_path\'\] = \'ci_sessions\';|g" /var/www/application/config/config.php \
  && encription=$(/usr/bin/php -r 'echo bin2hex(random_bytes(16)), "\n";') \
  && /bin/busybox sed -i "s|F0af18413d1c9e03A6d8d1273160f5Ed|$encription|g" /var/www/application/config/config.php

#Change kalkun_settings.php to disable append_username & set max sms per minute to 0.5/min
RUN /bin/busybox sed -i "s|\$config\[\'append_username\'\] = TRUE;|\$config\[\'append_username\'\] = FALSE;|g" /var/www/application/config/kalkun_settings.php \
  && /bin/busybox sed -i "s|\$config\[\'max_sms_sent_by_minute\'\] = 0;|\$config\[\'max_sms_sent_by_minute\'\] = 0.5;|g" /var/www/application/config/kalkun_settings.php 

#Set scripts path in daemon.sh & outbox_queue.sh
RUN /bin/busybox sed -i "s|path\/to\/kalkun|var\/www|g" /var/www/scripts/daemon.sh \
  && /bin/busybox sed -i "s|path\/to\/kalkun|var\/www|g" /var/www/scripts/outbox_queue.sh

#Configure database connection in database.php
RUN /bin/busybox sed -i "s|\'username\' => \'root\'|\'username\' => \'${dbuser}\'|g" /var/www/application/config/database.php \
  && /bin/busybox sed -i "s|\'password\' => \'password\'|\'password\' => \'${dbpass}\'|g" /var/www/application/config/database.php \
  && /bin/busybox sed -i "s|\'database\' => \'kalkun\'|\'database\' => \'${dbname}\'|g" /var/www/application/config/database.php \
  && /bin/busybox sed -i "s|\'hostname\' => \'127.0.0.1\'|\'hostname\' => \'${dbhostname}\'|g" /var/www/application/config/database.php

#Delete install file
RUN /bin/busybox rm /var/www/install

#Fix kalkun 0.8.0-rc1 kalkun_helper.php is_phone_number_valid() error
RUN /bin/busybox sed -i "s|tr(\'Please specify a valid mobile phone number\')|TRUE|g" /var/www/application/helpers/kalkun_helper.php \
  && /bin/busybox sed -i "s|\$e->getMessage()|TRUE|g" /var/www/application/helpers/kalkun_helper.php

# Set permissions
RUN /bin/busybox chown -R www:www /var/www \
  && /bin/busybox chown -R www:www /usr/share/nginx \
  && /bin/busybox chmod +x /etc/init.d/gammu-smsd \
  && /bin/busybox chmod +x /var/www/scripts/daemon.sh /var/www/scripts/daemon.php \
  && /bin/busybox chmod +x /var/www/scripts/outbox_queue.sh /var/www/scripts/outbox_queue.php \
  # Create autostart
  && /sbin/rc-update add gammu-smsd default \
  && /sbin/rc-update add php-fpm8 default \
  && /sbin/rc-update add nginx default \
  #Remove hostname & networking error
  && rm /etc/init.d/hostname && rm /etc/init.d/networking

VOLUME /opt/config
CMD ["openrc", "default"]