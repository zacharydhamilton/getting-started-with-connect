FROM debezium/example-postgres:2.0

RUN apt-get update
RUN apt-get -y install postgresql-15-cron*

RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
RUN locale-gen en_US.UTF-8

ENV POSTGRES_DB=postgres
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=c00l-p0stgr3s

RUN mkdir /data
COPY data/* /data/

RUN rm /docker-entrypoint-initdb.d/inventory.sql
COPY setup/setup_ecommerce.sql /docker-entrypoint-initdb.d/
ADD setup/setup_ecommerce.sql /docker-entrypoint-initdb.d

COPY setup/setup_configurations.sh /docker-entrypoint-initdb.d/
ADD setup/setup_configurations.sh /docker-entrypoint-initdb.d

RUN chmod a+r /docker-entrypoint-initdb.d/*
RUN chmod a+x /docker-entrypoint-initdb.d/setup_configurations.sh

EXPOSE 5432