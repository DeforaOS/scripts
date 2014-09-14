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



#environment
#variables
PROGNAME="deforaos-git-hook.sh"
#executables
GIT="git"
SED="sed"
SORT="sort"
UNIQ="uniq"


#functions
#count_lines
_count_lines()
{
	lines_cnt=0

	while read line; do
		lines_cnt=$((lines_cnt + 1))
	done
	echo "$lines_cnt"
}


#error
_error()
{
	echo "$PROGNAME: $@" 1>&2
	return 2
}


#hook_post_commit
_hook_post_commit()
{
	if [ $# -ne 0 ]; then
		_usage "post-commit"
		return $?
	fi
	while read oldrev newrev refname; do
		#XXX ignore errors
		_hook_update "$refname" "$oldrev" "$newrev"
	done
	return 0
}


#hook_post_receive
_hook_post_receive()
{
	if [ $# -ne 0 ]; then
		_usage "post-receive"
		return $?
	fi
	while read oldrev newrev refname; do
		#XXX ignore errors
		_hook_update "$refname" "$oldrev" "$newrev"
	done
	return 0
}


#hook_update
_hook_update()
{
	if [ $# -ne 3 ]; then
		_usage "update refname oldrev newrev"
		return $?
	fi
	refname="$1"
	oldrev="$2"
	newrev="$3"
	nullrev="0000000000000000000000000000000000000000"
	author="$GL_USER"
	[ -z "$author" ] && author="$USER"
	repository="$GL_REPO"
	branch=
	type="push"

	#analyze the push
	message=
	[ -n "$repository" ] && message="$repository: "
	[ -n "$author" ] && message="$message$author"
	branch=
	case "$refname" in
		refs/heads/*)
			branch=${refname#refs/heads/}
			[ -n "$branch" ] && message="$message [$branch]"
			type="branch"
			;;
		refs/tags/*)
			tag=${refname#refs/tags/}
			[ -n "$tag" ] && message="$message [$tag]"
			type="tag"
			;;
		*)
			[ -n "$refname" ] && message="$message [$refname]"
			;;
	esac
	if [ "$oldrev" = "$nullrev" ]; then
		message="$message new $type at $(_shorten 8 "$newrev")"
	elif [ "$newrev" = "$nullrev" ]; then
		message="$message $type deleted"
	else
		commit_cnt=0
		all_files=
		revisions=$($GIT rev-list "${oldrev}..${newrev}")
		type=$($GIT cat-file -t "$newrev")
		log=
		for revision in $revisions; do
			#$GIT cat-file commit "$revision"
			#obtain the first log message
			[ -z "$log" ] && log=$($GIT log -n 1 --oneline "$revision")
			#count the file alterations
			files=$($GIT log -n 1 --name-only --pretty=format:'' "$revision")
			all_files="$all_files$files"
			#count the number of commits
			commit_cnt=$((commit_cnt + 1))
		done
		all_files=$(echo "$all_files" | $SED -e '/^$/d')
		files_cnt=$(echo "$all_files" | _count_lines)
		unique_files_cnt=$(echo "$all_files" | $SORT | $UNIQ | _count_lines)
		if [ $commit_cnt -eq 1 -a -n "$log" ]; then
			message="$message $log"
		elif [ $commit_cnt -lt 2 ]; then
			message="$message $commit_cnt $type pushed"
		else
			message="$message $commit_cnt ${type}s pushed"
		fi
		message="$message ($files_cnt"
		if [ $files_cnt -lt 2 ]; then
			message="$message alteration"
		else
			message="$message alterations"
		fi
		if [ $unique_files_cnt -lt 2 ]; then
			message="$message in $unique_files_cnt file)"
		else
			message="$message in $unique_files_cnt files)"
		fi
	fi
	echo "$message"
	return 0
}


#shorten
_shorten()
{
	echo "$2" | $SED -e "s/^\\(.\\{$1\\}\\).*\$/\\1/"
}


#usage
_usage()
{
	if [ $# -gt 0 ]; then
		echo "Usage: $PROGNAME $@" 1>&2
	else
		echo "Usage: $PROGNAME [-O name=value...] hook [argument...]" 1>&2
	fi
	return 1
}


#main
#parse options
while getopts "O:" name; do
	case "$name" in
		O)
			export "${OPTARG%%=*}"="${OPTARG#*=}"
			;;
		*)
			_usage
			exit $?
			;;
	esac
done
shift $((OPTIND - 1))
if [ $# -eq 0 ]; then
	_usage
	exit $?
fi

hook="$1"
shift 1
case "$hook" in
	"post-commit")
		_hook_post_commit "$@"
		exit $?
		;;
	"post-receive")
		_hook_post_receive "$@"
		exit $?
		;;
	"update")
		_hook_update "$@"
		exit $?
		;;
	*)
		_error "$hook: Unknown hook"
		exit $?
		;;
esac
