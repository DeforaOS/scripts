#!/bin/sh
#$Id$
#Copyright (c) 2016-2017 Pierre Pronchery <khorben@defora.org>
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



#environment
#variables
JOIN="/j"
NOTICE="/NOTICE"
PREFIX="/var/tmp/ii"
PRIVMSG="/j"
NOTICE="/NOTICE"
PROGNAME="deforaos-irc.sh"
QUIT="/QUIT"
#executables
FORTUNE="fortune -s -n 50"
HEAD="head"
II="ii -i $PREFIX"
KILL="kill"
RM="rm -f"
SLEEP="sleep 1"
TR="tr"


#functions
#irc
_irc()
{
	if [ $# -ne 4 ]; then
		_usage
		return 1
	fi
	ret=0
	pid=
	server=$(echo "$1" | $TR A-Z a-z)
	port="$2"
	nickname="$3"
	channel=$(echo "$4" | $TR A-Z a-z)
	serverin="$PREFIX/$server/in"
	channelin="$PREFIX/$server/$channel/in"

	#connect to the server
	if [ ! -w "$serverin" ]; then
		_info "$server: Connecting to server"
		#FIXME really keep track of pid
		$II -s "$server" -p "$port" -n "$nickname" &
		pid=0
	fi
	#wait until the server is connected to
	loop=0
	while [ ! -w "$serverin" ]; do
		$SLEEP
		loop=$((loop + 1))
		if [ $loop -ge 10 ]; then
			ret=2
			break
		fi
	done
	#initiate query
	if [ "${channel###*}" = "${channel}" ]; then
		#output the text
		while read line; do
			if [ $notice -eq 0 ]; then
				_info "$channel: Messaging user"
				output="$PRIVMSG $channel $line"
			else
				_info "$channel: Notifying user"
				output="$NOTICE $channel :$line"
			fi
			echo "$output"
			$SLEEP
		done > "$serverin"
	else
		#join the channel
		if [ ! -w "$channelin" ]; then
			_info "$channel: Joining channel"
			echo "$JOIN $channel" > "$serverin"
		fi
		#wait until the channel is joined
		loop=0
		while [ ! -w "$channelin" ]; do
			$SLEEP
			loop=$((loop + 1))
			if [ $loop -ge 10 ]; then
				ret=3
				break
			fi
		done
		#output the text
		if [ $ret -eq 0 ]; then
			if [ $notice -eq 0 ]; then
				_info "$channel: Joined channel"
				while read line; do
					echo "$line"
					$SLEEP
				done > "$channelin"
			else
				_info "$channel: Notifying channel"
				while read line; do
					echo "$NOTICE $channel :$line"
					$SLEEP
				done > "$serverin"
			fi
		else
			_error "$channel: Could not join channel"
		fi
	fi
	if [ -n "$pid" ]; then
		#quit the server
		_info "$server: Disconnecting from server"
		echo "$QUIT :$($FORTUNE | $HEAD -n 1)" > "$serverin"
		#wait until the server is disconnected
		#FIXME ii does not automatically clean up when quitting
		loop=0
		while [ ! -w "$channelin" ]; do
			$SLEEP
			loop=$((loop + 1))
			if [ $loop -ge 10 ]; then
				ret=4
				break
			fi
		done
		#force quit the server if necessary
		[ $ret -eq 0 ] || $KILL "$pid"
		$RM -- "$serverin" "$channelin"
	fi
	return $ret
}


#error
_error()
{
	echo "$PROGNAME: $@" 1>&2
	return 2
}


#info
_info()
{
	[ $verbose -eq 0 ] || echo "$PROGNAME: $@"
}


#usage
_usage()
{
	echo "Usage: $PROGNAME [-Nqv] -s server -c channel [-n nickname]" 1>&2
	echo "  -n	Use notice" 1>&2
	echo "  -q	Quiet mode (default)" 1>&2
	echo "  -v	Be more verbose" 1>&2
	return 1
}


#main
#parse options
channel=
nickname="$USER"
notice=0
port=6667
server=
verbose=0
while getopts "c:Nn:qs:v" name; do
	case "$name" in
		c)
			channel="$OPTARG"
			;;
		N)
			notice=1
			;;
		n)
			nickname="$OPTARG"
			;;
		p)
			port="$OPTARG"
			;;
		q)
			verbose=0
			;;
		s)
			server="$OPTARG"
			;;
		v)
			verbose=$((verbose + 1))
			;;
		*)
			_usage
			exit $?
			;;
	esac
done
if [ -z "$server" -o -z "$channel" ]; then
	_usage
	exit $?
fi

_irc "$server" "$port" "$nickname" "$channel"
