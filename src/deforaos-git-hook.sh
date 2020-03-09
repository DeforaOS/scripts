#!/bin/sh
#Copyright (c) 2014-2020 Pierre Pronchery <khorben@defora.org>
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions
#are met:
#1. Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#2. Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#
#THIS SOFTWARE IS PROVIDED BY THE EDGEBSD PROJECT AND CONTRIBUTORS
#``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
#TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
#PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
#BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
#INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
#CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
#ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#POSSIBILITY OF SUCH DAMAGE.



#variables
PREFIX="/usr/local"
GIT_GITWEB="https://git.defora.org/gitweb"
HOOKS="irc jobs"
IRC_CHANNEL="#DeforaOS"
IRC_SERVER="irc.oftc.net"
JOBS_BRANCH_MASTER="$PREFIX/libexec/deforaos-git-mirror.sh
$PREFIX/libexec/deforaos-git-doc.sh
$PREFIX/libexec/deforaos-git-tests.sh"
#executables
GIT="/usr/bin/git"
GIT_MESSAGE="$PREFIX/libexec/deforaos-git-message.sh"
IRC="$PREFIX/libexec/deforaos-irc.sh -N -s $IRC_SERVER -c $IRC_CHANNEL -n defora"
JOBS="$PREFIX/bin/deforaos-jobs.sh -d /home/jobs/DeforaOS"
MKTEMP="/bin/mktemp"
RM="/bin/rm -f"


#functions
#hook_jobs
_hook_jobs()
{
	while read oldrev newrev refname; do
		case "$refname" in
			refs/heads/*)
				_jobs_branch "${refname#refs/heads/}" "$GL_REPO"
				;;
		esac
	done
	return $ret
}

_jobs_branch()
{
	branch="$1"
	repository="$2"

	if [ "$branch" = "master" -a -n "$JOBS_BRANCH_MASTER" ]; then
		for job in $JOBS_BRANCH_MASTER; do
			$JOBS add "$job $repository"
		done
	fi
}


#hook_irc
_hook_irc()
{
	$GIT_MESSAGE -O GITWEB="$GIT_GITWEB" "post-receive" | $IRC
	#ignore errors
	return 0
}


#main
#save a copy of the output
tmpfile=$($MKTEMP)
[ $? -eq 0 ]							|| exit 2
while read line; do
	echo "$line" >> "$tmpfile"
done
#chain the hooks
ret=0
[ -n "$HOOKS" ] && for hook in $HOOKS; do
	"_hook_$hook" < "$tmpfile"				|| ret=2
done
#clean up
$RM -- "$tmpfile"						|| exit 2

exit $ret
