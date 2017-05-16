Alpine Oracle REST Data Services Docker image
=============================================

This image is based on Alpine tomcat image ([tomcat:9-alpine](https://hub.docker.com/_/tomcat/)), which is only a 75MB image, and provides a docker image for Oracle REST Data Services.

Prerequisites
-------------

- If you want to build this image, you will need to download [Oracle REST Data Services 3.0.9.348.07.16](http://www.oracle.com/technetwork/developer-tools/rest-data-services/downloads/index.html) and [Oracle SQLcl 4.2.0.17.097.0719](http://www.oracle.com/technetwork/developer-tools/sqlcl/downloads/index.html).

Usage Example
-------------

This image is intended to be a base image for your projects, so you may use it like this:

```Dockerfile
FROM cosmomill/alpine-ords-apex
```

```sh
$ docker build -t my_app . --build-arg ORDS_FILE="ords.3.0.9.348.07.16.zip" --build-arg SQLCL_FILE="sqlcl-4.2.0.17.097.0719-no-jre.zip"
```

```sh
$ docker run -d -P --link <your cosmomill/alpine-oracle-xe container>:db --volumes-from <your cosmomill/alpine-oracle-xe container> -v ords_config:/opt -e DATABASE_HOSTNAME="db" -p 8080:8080 cosmomill/alpine-ords-apex
```

The default list of ENV variables is:

```
DATABASE_HOSTNAME=
ORACLE_SID=XE
DATABASE_PORT=1521
```

Connect to database
-------------------

Auto generated passwords are stored in separate hidden files in ```/u01/app/oracle/oradata/dbconfig/XE``` with the naming system ```.username.passwd```.
