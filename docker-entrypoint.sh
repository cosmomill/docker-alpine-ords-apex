#!/bin/bash

# stop on errors
set -e

# check whether ORDS configuration already exists
if [ -d "$ORDS_CONFIG_DIR/ords" ]; then
	echo "Oracle REST Data Services configuration found."
else
	mkdir $TOMCAT_HOME/webapps/params

	if [ -d "$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID" ]; then
		if [ -f "$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.apex_public_user.passwd" ]; then
			APEX_PUBLIC_USER_PWD=${APEX_PUBLIC_USER_PWD:-"`cat $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.apex_public_user.passwd`"}
		else
			# auto generate APEX_PUBLIC_USER password if not passed on
			APEX_PUBLIC_USER_PWD=${APEX_PUBLIC_USER_PWD:-"`tr -dc A-Za-z0-9 < /dev/urandom | head -c8`"}
			# store APEX_PUBLIC_USER password
			APEX_PUBLIC_USER_PWD_FILE=$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.apex_public_user.passwd
			echo -n $APEX_PUBLIC_USER_PWD > $APEX_PUBLIC_USER_PWD_FILE
			chmod 600 $APEX_PUBLIC_USER_PWD_FILE
			chown root:root $APEX_PUBLIC_USER_PWD_FILE
		fi;

		if [ -f "$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.ords_public_user.passwd" ]; then
			ORDS_PUBLIC_USER_PWD=${ORDS_PUBLIC_USER_PWD:-"`cat $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.ords_public_user.passwd`"}
		else
			# auto generate ORDS_PUBLIC_USER password if not passed on
			ORDS_PUBLIC_USER_PWD=${ORDS_PUBLIC_USER_PWD:-"`tr -dc A-Za-z0-9 < /dev/urandom | head -c8`"}
			# store ORDS_PUBLIC_USER password
			ORDS_PUBLIC_USER_PWD_FILE=$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.ords_public_user.passwd
			echo -n $ORDS_PUBLIC_USER_PWD > $ORDS_PUBLIC_USER_PWD_FILE
			chmod 600 $ORDS_PUBLIC_USER_PWD_FILE
			chown root:root $ORDS_PUBLIC_USER_PWD_FILE
		fi;
	else
			echo "Oracle configuration folder not found, run docker with: --volumes-from cosmomill/alpine-oracle-xe."
			exit 1
	fi;

	if [ -f "$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.sysdba.passwd" ]; then
		SYSDBA_PWD=${SYSDBA_PWD:-"`cat $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.sysdba.passwd`"}
	else
		echo "Password for SYSDBA user not found, run docker-apex-update.sh on cosmomill/alpine-oracle-xe."
		exit 1
	fi;

	if [ -f "$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.apex_listener.passwd" ]; then
		APEX_LISTENER_PWD=${APEX_LISTENER_PWD:-"`cat $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.apex_listener.passwd`"}
	else
		echo "Password for APEX_LISTENER user not found, run docker-apex-update.sh on cosmomill/alpine-oracle-xe."
		exit 1
	fi;

	if [ -f "$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.apex_rest_public_user.passwd" ]; then
		APEX_REST_PUBLIC_USER_PWD=${APEX_REST_PUBLIC_USER_PWD:-"`cat $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.apex_rest_public_user.passwd`"}
	else
		echo "Password for APEX_REST_PUBLIC_USER user not found, run docker-apex-update.sh on cosmomill/alpine-oracle-xe."
		exit 1
	fi;

	# update values from environment variables
	echo "db.hostname=$DATABASE_HOSTNAME
db.password=$APEX_PUBLIC_USER_PWD
db.port=$DATABASE_PORT
db.servicename=$ORACLE_SID
db.username=APEX_PUBLIC_USER
schema.tablespace.default=SYSAUX
schema.tablespace.temp=TEMP
user.tablespace.default=USERS
user.tablespace.temp=TEMP
migrate.apex.rest=false
plsql.gateway.add=true
rest.services.apex.add=true
rest.services.ords.add=true
standalone.mode=false
user.apex.listener.password=$APEX_LISTENER_PWD
user.apex.restpublic.password=$APEX_REST_PUBLIC_USER_PWD
user.public.password=$ORDS_PUBLIC_USER_PWD
sys.user=sys
sys.password=$SYSDBA_PWD" > $TOMCAT_HOME/webapps/params/ords_params.properties

	java -jar $TOMCAT_HOME/webapps/ords.war

	sqlcl SYS/$SYSDBA_PWD@$DATABASE_HOSTNAME:$DATABASE_PORT:$ORACLE_SID as SYSDBA <<EOF
alter user APEX_PUBLIC_USER identified by "$APEX_PUBLIC_USER_PWD" account unlock;
alter user ORDS_PUBLIC_USER identified by "$ORDS_PUBLIC_USER_PWD" account unlock;
alter user APEX_PUBLIC_USER profile APEX_PUBLIC;
alter user ORDS_PUBLIC_USER profile APEX_PUBLIC;
exit;
EOF

	# optimize ORDS
	sed -i '/<entry key="db.username">APEX_PUBLIC_USER<\/entry>/a <entry key="jdbc.InitialLimit">10<\/entry>' $ORDS_CONFIG_DIR/ords/conf/apex.xml
	sed -i '/<entry key="jdbc.InitialLimit">10<\/entry>/a <entry key="jdbc.MinLimit">10<\/entry>' $ORDS_CONFIG_DIR/ords/conf/apex.xml
	sed -i '/<entry key="jdbc.MinLimit">10<\/entry>/a <entry key="jdbc.MaxLimit">60<\/entry>' $ORDS_CONFIG_DIR/ords/conf/apex.xml

fi;

# check whether APEX images folder exists and create symlink
if [ "$(ls -A $ORACLE_HOME/apex/images)" ]; then
		echo "APEX images folder found."
		ln -sfn $ORACLE_HOME/apex/images $TOMCAT_HOME/webapps/i
	else
		echo "APEX images folder not found, run docker with: --volumes-from cosmomill/alpine-oracle-xe."
		exit 1
fi;

echo
echo "Oracle REST Data Services init process done. Ready for start up."
echo

exec catalina.sh "$1"
