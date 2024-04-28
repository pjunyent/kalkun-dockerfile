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
RUN wget -q https://github.com/kalkun-sms/Kalkun/releases/download/v0.8.2.1/Kalkun_v0.8.2.1_forPHP8.2.tar.xz -O kalkun.tar.xz \
    && mkdir kalkun \
    && tar -Jxf kalkun.tar.xz -C ./kalkun --strip-components=1\
    && mv ./kalkun/application/sql/mysql/kalkun.sql /docker-entrypoint-initdb.d/2-kalkun.sql \
    && mv ./kalkun/application/sql/mysql/pbk_gammu.sql /docker-entrypoint-initdb.d/3-pbk_gammu.sql \
    && mv ./kalkun/application/sql/mysql/pbk_kalkun.sql /docker-entrypoint-initdb.d/4-pbk_kalkun.sql

#Clean kalkun
RUN rm -rf ./kalkun \
    && rm kalkun.tar.xz
