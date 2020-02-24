#!/bin/sh
#Copyright (c) 2014-2019 Pierre Pronchery <khorben@defora.org>
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
GIT_GITWEB="https://git.defora.org/gitweb"
GIT_MIRROR="/home/defora/git"
GIT_REMOTE="origin"
HOOKS="mirror irc"
IRC_CHANNEL="#DeforaOS"
IRC_SERVER="irc.oftc.net"
PREFIX="/usr/local"
#executables
GIT="/usr/bin/git"
GIT_MESSAGE="$PREFIX/libexec/deforaos-git-message.sh"
IRC="$PREFIX/libexec/deforaos-irc.sh -N -s $IRC_SERVER -c $IRC_CHANNEL -n defora"
MKTEMP="/bin/mktemp"
RM="/bin/rm -f"


#functions
#hook_irc
_hook_irc()
{
	$GIT_MESSAGE -O GITWEB="$GIT_GITWEB" "post-receive" | $IRC
	#ignore errors
	return 0
}


#hook_mirror
_hook_mirror()
{
	ret=0

	[ -d "$GIT_MIRROR" ]					|| return 2
	while read oldrev newrev refname; do
		branch=
		case "$refname" in
			refs/heads/*)
				branch=${refname#refs/heads/}
				;;
		esac
		[ "$branch" = "master" ] || continue
		mirror="$GIT_MIRROR/${GL_REPO}.git"
		if [ ! -d "$mirror" ]; then
			#clone the repository
			$GIT clone "$HOME/repositories/${GL_REPO}.git" "$mirror"
			if [ $? -ne 0 ]; then
				echo "$GL_REPO: Could not create mirror" 1>&2
				continue
			fi
		fi
		#mirror the repository
		(unset GIT_DIR;
			cd "$mirror" &&
			$GIT fetch -q "$GIT_REMOTE" &&
			$GIT reset -q --hard "$GIT_REMOTE/$branch") || ret=2
	done
	return $ret
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
for hook in $HOOKS; do
	"_hook_$hook" < "$tmpfile"				|| ret=2
done
#clean up
$RM -- "$tmpfile"						|| exit 2

exit $ret
