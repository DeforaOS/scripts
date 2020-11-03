#!/bin/sh
#Copyright (c) 2020 Pierre Pronchery <khorben@defora.org>
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
GIT_MIRROR="/home/defora/git"
GIT_REMOTE="origin"
PROGNAME_GIT_MIRROR="deforaos-git-mirror.sh"
#executables
GIT="git"
GIT_CLONE="$GIT clone -q"
GIT_FETCH="$GIT fetch -q"
GIT_RESET="$GIT reset -q"


#functions
#git_mirror
_git_mirror()
{
	repository="$1"
	mirror="$GIT_MIRROR/${repository}.git"

	if [ ! -d "$mirror" ]; then
		#clone the repository
		$GIT_CLONE "$HOME/repositories/${repository}.git" "$mirror"
		if [ $? -ne 0 ]; then
			echo "$repository: Could not create mirror" 1>&2
			continue
		fi
	fi
	#mirror the repository
	(cd "$mirror" &&
		$GIT_FETCH "$GIT_REMOTE" &&
		$GIT_RESET --hard "$GIT_REMOTE/$branch")	|| return 2
}


#usage
_usage()
{
	echo "Usage: $PROGNAME_GIT_MIRROR repository" 1>&2
	return 1
}


#main
if [ $# -ne 1 ]; then
	_usage
	exit $?
fi
_git_mirror "$1"
