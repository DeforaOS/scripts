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
WC="wc"


#functions
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
	author="$GL_USER"
	repository="$GL_REPO"
	branch=
	type=$($GIT cat-file -t "$newrev")

	case "$refname" in
		refs/heads/*)
			branch=${refname#refs/heads/}
			;;
	esac

	#analyze each commit pushed
	revisions=$($GIT rev-list "${oldrev}..${newrev}")
	message=
	commit_cnt=0
	all_files=
	for revision in $revisions; do
		#$GIT cat-file commit "$revision"
		#count the file alterations
		files=$($GIT log -n 1 --name-only --pretty=format:'' "$revision")
		[ -z "$message" ] && message=$($GIT log -n 1 --oneline "$revision")
		all_files="$all_files$files"
		#count the number of commits
		commit_cnt=$((commit_cnt + 1))
	done
	all_files=$(echo "$all_files" | $SED -e '/^$/d')
	files_cnt=$(echo "$all_files" | $WC -l)
	unique_files_cnt=$(echo "$all_files" | $SORT | $UNIQ | $WC -l)
	if [ -n "$branch" ]; then
		if [ $commit_cnt -eq 1 -a -n "$message" ]; then
			echo "$repository: $author [$branch] $message ($files_cnt alterations in $unique_files_cnt files)"
		else
			echo "$repository: $author [$branch] $commit_cnt $type(s) pushed ($files_cnt alterations in $unique_files_cnt files)"
		fi
	else
		echo "$repository: $author [$refname] $commit_cnt $type(s) pushed ($files_cnt alterations in $unique_files_cnt files)"
	fi
	return 0
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
