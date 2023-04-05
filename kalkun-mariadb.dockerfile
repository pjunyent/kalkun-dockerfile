#(c) pjunyent, EUPL v.1.2
#syntax=docker/dockerfile:1
FROM mariadb:latest

#Install wget
RUN apt-get update && apt-get install -y \
    wget \
    && rm -rf /var/lib/apt/lists/*

#Download and load gammu sql database
RUN wget https://raw.githubusercontent.com/gammu/gammu/master/docs/sql/mysql.sql -O mysql.sql \
    && mv mysql.sql /docker-entrypoint-initdb.d/1-mysql.sql

#Download and load kalkun sql database
RUN wget -q https://github.com/kalkun-sms/Kalkun/releases/download/v0.8.0-rc-1/Kalkun_v0.8.0-rc-1_forPHP8.1.tar.xz -O kalkun.tar.xz \
    && tar -Jxvf kalkun.tar.xz \
    && mv ./Kalkun_v0.8.0-rc-1_forPHP8.1/application/sql/mysql/kalkun.sql /docker-entrypoint-initdb.d/2-kalkun.sql \
    && mv ./Kalkun_v0.8.0-rc-1_forPHP8.1/application/sql/mysql/pbk_gammu.sql /docker-entrypoint-initdb.d/3-pbk_gammu.sql \
    && mv ./Kalkun_v0.8.0-rc-1_forPHP8.1/application/sql/mysql/pbk_kalkun.sql /docker-entrypoint-initdb.d/4-pbk_kalkun.sql

#Clean kalkun
RUN rm -rf ./Kalkun_v0.8.0-rc-1_forPHP8.1 \
    && rm kalkun.tar.xz