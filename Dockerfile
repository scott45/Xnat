# running database build
FROM postgres:9.4-alpine as db

WORKDIR /postgres

RUN apk update \
 && apk add ca-certificates openssl && rm -f /var/cache/apk/* && \
 wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.4/gosu-amd64" && \
 chmod +x /usr/local/bin/gosu && \
 echo "Success"

ADD scripts/run.sh run.sh
RUN mkdir ./pre-exec.d && \
 mkdir ./pre-init.d && \
 chmod -R 755 run.sh

RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql

ENV LANG en_US.utf8
ENV PGDATA /var/lib/postgresql/data
VOLUME ["/var/lib/postgresql/data"]

EXPOSE 5432

# ENTRYPOINT ["/scripts/run.sh"]

# app build
FROM tomcat:7-jre8-alpine

WORKDIR /app

COPY --from=db /postgres .

RUN apk add --no-cache wget nginx postgresql postgresql-client postgresql-dev supervisor

RUN wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.4/gosu-amd64" && \
    chmod +x /usr/local/bin/gosu
    
VOLUME ["/var/lib/postgresql/data"]

ENV POSTGRES_USER xnat
ENV POSTGRES_PASSWORD xnat
ENV POSTGRES_DB xnat
ENV PGDATA /var/lib/postgresql/data

RUN mkdir -p /run/nginx
RUN rm /etc/nginx/conf.d/default.conf 
COPY /nginx/nginx.conf /etc/nginx

RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql

COPY /postgres/XNAT.sql /docker-entrypoint-initdb.d/

ARG XNAT_VER=1.7.5.1
ARG XNAT_ROOT=/data/xnat
ARG XNAT_HOME=/data/xnat/home
ARG XNAT_DATASOURCE_DRIVER=org.postgresql.Driver
ARG XNAT_DATASOURCE_URL=jdbc:postgresql://xnat:xnat@localhost:5432/xnat
ARG XNAT_DATASOURCE_USERNAME=xnat
ARG XNAT_DATASOURCE_PASSWORD=xnat
ARG XNAT_HIBERNATE_DIALECT=org.hibernate.dialect.PostgreSQL9Dialect
ARG TOMCAT_XNAT_FOLDER=ROOT
ARG SMTP_ENABLED=false
ARG SMTP_HOSTNAME=fake.fake
ARG SMTP_PORT
ARG SMTP_AUTH
ARG SMTP_USERNAME
ARG SMTP_PASSWORD

ADD /xnat/wait-for-postgres.sh /usr/local/bin/wait-for-postgres.sh
ADD /xnat/make-xnat-config.sh /usr/local/bin/make-xnat-config.sh

RUN rm -rf $CATALINA_HOME/webapps/* && \
    mkdir -p \
        $CATALINA_HOME/webapps/${TOMCAT_XNAT_FOLDER} \
        ${XNAT_HOME}/config \
        ${XNAT_HOME}/logs \
        ${XNAT_HOME}/plugins \
        ${XNAT_HOME}/work \
        ${XNAT_ROOT}/archive \
        ${XNAT_ROOT}/build \
        ${XNAT_ROOT}/cache \
        ${XNAT_ROOT}/ftp \
        ${XNAT_ROOT}/pipeline \
        ${XNAT_ROOT}/prearchive \
    && \
    /usr/local/bin/make-xnat-config.sh && \
    rm /usr/local/bin/make-xnat-config.sh && \
    cd $CATALINA_HOME/webapps/ && \
    wget https://api.bitbucket.org/2.0/repositories/xnatdev/xnat-web/downloads/xnat-web-${XNAT_VER}.war && \
    cd ${TOMCAT_XNAT_FOLDER} && \
    unzip -o ../xnat-web-${XNAT_VER}.war && \
    rm -f ../xnat-web-${XNAT_VER}.war && \
    apk del wget

EXPOSE 8080 5432 80
ENV XNAT_HOME=${XNAT_HOME} XNAT_DATASOURCE_USERNAME=${XNAT_DATASOURCE_USERNAME}

ADD supervisord.conf /etc/

CMD ["supervisord"]

# CMD ["wait-for-postgres.sh", "/usr/local/tomcat/bin/catalina.sh", "run"]