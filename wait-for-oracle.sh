#!/bin/sh

TIMEOUT=15
QUIET=0

echoerr() {
	if [ "$QUIET" -ne 1 ]; then printf "%s\n" "$*" 1>&2; fi
}

usage() {
	EXITCODE="$1"
	cat << USAGE >&2
Usage:
  $cmdname [-t timeout] [-- command args]
  -q | --quiet                        Do not output any status messages
  -t TIMEOUT | --timeout=timeout      Timeout in seconds, zero for no timeout
  -- COMMAND ARGS                     Execute command with args after the test finishes
USAGE
	exit "$EXITCODE"
}

wait_for() {
	TEMP_FILE=$(mktemp)
	for i in `seq $TIMEOUT` ; do
		# test to see if Oracle is accepting connections
		sqlcl SYS/$SYSDBA_PWD@$DATABASE_HOSTNAME:$DATABASE_PORT:$ORACLE_SID as SYSDBA <<EOF > $TEMP_FILE
  select * from v\$database;
exit
EOF

		CHECK_STAT=`cat $TEMP_FILE|grep -i error|wc -l`;
		ORACLE_NUM=`expr $CHECK_STAT`

		if [ $ORACLE_NUM -eq 0 ]; then
			if [ $# -gt 0 ]; then
				exec "$@"
			fi
			exit 0
		fi
		sleep 2
	done
	echo "Operation timed out" >&2
	rm $TEMP_FILE
	exit 1
}

while [ $# -gt 0 ]; do
	case "$1" in
		-q | --quiet)
		QUIET=1
		shift 1
		;;
		-t)
		TIMEOUT="$2"
		if [ "$TIMEOUT" = "" ]; then break; fi
		shift 2
		;;
		--timeout=*)
		TIMEOUT="${1#*=}"
		shift 1
		;;
		--)
		shift
		break
		;;
		--help)
		usage 0
		;;
		*)
		echoerr "Unknown argument: $1"
		usage 1
		;;
	esac
done

if [ -f "$ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.sysdba.passwd" ]; then
	SYSDBA_PWD=${SYSDBA_PWD:-"`cat $ORACLE_BASE/oradata/dbconfig/$ORACLE_SID/.sysdba.passwd`"}
else
	echo "Password for SYSDBA user not found, run docker with: --volumes-from host $DATABASE_HOSTNAME."
	exit 1
fi;

wait_for "$@"