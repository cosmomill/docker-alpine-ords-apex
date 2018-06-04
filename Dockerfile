FROM tomcat:9-alpine

MAINTAINER Rene Kanzler, me at renekanzler dot com

# add bash to make sure our scripts will run smoothly
RUN apk --update add --no-cache bash

# install bsdtar
RUN apk --update add --no-cache libarchive-tools

ONBUILD ARG ORDS_FILE
ONBUILD ARG SQLCL_FILE

ENV TZ GMT
ENV ORDS_VERSION 18.1.1.95.1251
ENV ORDS_CONFIG_DIR /opt
ENV TOMCAT_HOME /usr/local/tomcat
ENV ORACLE_BASE /u01/app/oracle
ENV ORACLE_HOME /u01/app/oracle/product/11.2.0/xe
ENV ORACLE_SID XE
ENV DATABASE_PORT 1521

# install ORDS
ONBUILD ADD $ORDS_FILE /tmp/
ONBUILD RUN bsdtar -C $TOMCAT_HOME/webapps/ -xf /tmp/ords.$ORDS_VERSION.zip ords.war \
	&& rm -f ords.$ORDS_VERSION.zip

# set ORDS config directory
ONBUILD RUN java -jar $TOMCAT_HOME/webapps/ords.war configdir $ORDS_CONFIG_DIR

ENV SQLCL_VERSION 18.1.1

# install SQLcl
ONBUILD ADD $SQLCL_FILE /tmp/
ONBUILD RUN mkdir -p /var/lib/sqlcl && bsdtar --strip-components=2 -C /var/lib/sqlcl -xf /tmp/sqlcl-$SQLCL_VERSION.zip sqlcl/lib/* \
	\
	&& echo $'#!/bin/sh\n\
\n\
java -jar /var/lib/sqlcl/oracle.sqldeveloper.sqlcl.jar $@\n' > /usr/local/bin/sqlcl \
	\
	&& chmod 755 /usr/local/bin/sqlcl \
	&& rm -f sqlcl-$SQLCL_VERSION.zip

# define mountable directories
ONBUILD VOLUME /opt

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 8080
CMD ["run"]
