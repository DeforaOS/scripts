#!/bin/sh
#Copyright (c) 2020 Pierre Pronchery <khorben@defora.org>
#Error codes:
#  1	Usage error
#  2	Generic error
#  3	Could not lock the database
#  4	Could not unlock the database



#variables
DATABASE_CONFFILE="deforaos-jobs.conf"
DATABASE_ENGINE="sqlite3"
DATABASE_FILE="deforaos-jobs.db"
DATABASE_INITFILE="deforaos-jobs.sql"
DEVNULL="/dev/null"
PROGNAME_JOBS="defora-jobs"
QUERY_ADD_BEGIN="INSERT INTO jobs (command) VALUES ('"
QUERY_ADD_END="')"
QUERY_EXEC_SELECT="SELECT jobs_id, command FROM jobs WHERE started IS NULL ORDER BY jobs_id ASC LIMIT 1"
QUERY_INIT="CREATE TABLE jobs (jobs_id INTEGER PRIMARY KEY, timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, command VARCHAR(255), started TIMESTAMP DEFAULT NULL, pid INTEGER DEFAULT NULL, code INTEGER DEFAULT NULL, completed TIMESTAMP DEFAULT NULL)"
QUERY_LIST="SELECT * FROM jobs"
#executables
DATABASE="database"
DEBUG=
LOCK="mkdir"
UNLOCK="rmdir"
SED="sed"


#functions
#database_add
_database_add()
{
	if [ $# -ne 1 ]; then
		_usage
		return $?
	fi
	command="$1"
	query="$QUERY_ADD_BEGIN$(echo "$command" | _database_escape)$QUERY_ADD_END"

	_database_init						|| return 2
	_database_query "$query" > "$DEVNULL"			|| return 2
}


#database_escape
_database_escape()
{
	$SED -e "s,','',"
}


#database_exec
_database_exec()
{
	if [ $# -ne 0 ]; then
		_usage
		return $?
	fi

	_database_init						|| return 2
	_database_lock						|| return 3
	_database_query "$QUERY_EXEC_SELECT" | (IFS="|"
	read header
	read empty jobs_id command empty
	if [ -z "$jobs_id" ]; then
		_database_unlock				|| return 4
		return 0
	fi
	#XXX TOCTOU
	QUERY="UPDATE jobs SET started=datetime() WHERE jobs_id='$jobs_id'"
	_database_query "$QUERY" > "$DEVNULL"
	_database_unlock
	code=-1
	if [ -n "$command" ]; then
		$DEBUG sh -c "$command" &
		pid=$!
		QUERY="UPDATE jobs SET pid='$pid' WHERE jobs_id='$jobs_id'"
		_database_query "$QUERY" > "$DEVNULL"
		wait $pid
		code=$?
	fi
	QUERY="UPDATE jobs SET completed=datetime(), code='$code' WHERE jobs_id='$jobs_id'"
	_database_query "$QUERY" > "$DEVNULL")
}


#database_init
_database_init()
{
	if [ ! -f "$DATABASE_CONFFILE" ]; then
		echo "filename=$DATABASE_FILE" > "$DATABASE_CONFFILE"
	fi
	if [ ! -f "$DATABASE_FILE" ]; then
		_database_lock					|| return 3
		_database_query "$QUERY_INIT" > "$DEVNULL"	|| return 2
		_database_unlock				|| return 4
	fi
	return 0
}


#database_list
_database_list()
{
	if [ $# -ne 0 ]; then
		_usage
		return $?
	fi
	_database_init						|| return 2
	_database_query "$QUERY_LIST"				|| return 2
}


#database_lock
_database_lock()
{
	$DEBUG $LOCK "${DATABASE_FILE%.db}"
}


#database_query
_database_query()
{
	$DEBUG $DATABASE -d "$DATABASE_ENGINE" -C "$DATABASE_CONFFILE" "$@"
}


#database_unlock
_database_unlock()
{
	$DEBUG $UNLOCK "${DATABASE_FILE%.db}"
}


#debug
_debug()
{
	echo "$@" 1>&3
	"$@"
}


#error
_error()
{
	echo "$PROGNAME_JOBS: $@" 1>&2
	return 2
}


#usage
_usage()
{
	echo "Usage: $PROGNAME_JOBS [-d directory] add command" 1>&2
	echo "       $PROGNAME_JOBS [-d directory] exec" 1>&2
	echo "       $PROGNAME_JOBS [-d directory] list" 1>&2
	return 1
}


#main
directory=
while getopts "DO:d:" name; do
	case "$name" in
		D)
			DEBUG="_debug"
			;;
		O)
			export "${OPTARG%%=*}"="${OPTARG#*=}"
			;;
		d)
			directory="$OPTARG"
			;;
		?)
			_usage
			exit $?
			;;
	esac
done
shift $((OPTIND - 1))
if [ $# -lt 1 ]; then
	_usage
	exit $?
fi

exec 3>&1

method="_usage"
case "$1" in
	add|list|exec)
		method="_database_$1"
		;;
	*)
		_error "$1: Operation not supported"
		;;
esac
shift

if [ -n "$directory" ]; then
	(cd "$directory" && "$method" "$@")
else
	"$method" "$@"
fi
