#!/bin/sh
#$Id$
#Copyright (c) 2014 Pierre Pronchery <khorben@defora.org>
#This file is part of DeforaOS Devel scripts
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, version 3 of the License.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.



#variables
PROGNAME="deforaos-lock.sh"
#executables
LOCK="mkdir"
UNLOCK="rmdir"


#functions
#lock
_lock()
{
	lockfile="/var/tmp/deforaos-lock.$1"

	$LOCK -- "$lockfile"					|| return 2
	"$@"
	ret=$?
	$UNLOCK -- "$lockfile"
	return $ret
}


#usage
_usage()
{
	echo "Usage: $PROGNAME -- command [arguments...]" 1>&2
	return 1
}


#main
#parse the arguments
while getopts "" name; do
	case $name in
		*)
			_usage
			exit $?
			;;
	esac
done

#check the usage
shift $(($OPTIND - 1))
if [ $# -eq 0 ]; then
	_usage
	exit $?
fi

_lock "$@"
