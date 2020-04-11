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
PREFIX="/usr/local"
GIT_BRANCH="master"
GIT_REMOTE="https://git.defora.org"
DATADIR="$PREFIX/share"
MIRROR="doc:doc"
PROGNAME_GIT_DOC="deforaos-git-doc.sh"
#executables
CONFIGURE="/usr/local/bin/configure"
GIT="git"
GIT_CLONE="$GIT clone -q"
MAKE="make"
MKTEMP="mktemp"
RM="/bin/rm -f"
RSYNC="rsync -a"


#functions
#git_tests
_git_tests()
{
	ret=0
	repository="$1"

	#create a temporary directory
	tmpdir=$($MKTEMP -d)
	if [ $? -ne 0 ]; then
		return 2
	fi
	#clone the repository
	$GIT_CLONE --single-branch -b "$GIT_BRANCH" \
		"$GIT_REMOTE/${repository}.git" "$tmpdir/repository"
	if [ $? -ne 0 ]; then
		echo "$repository: Could not clone" 1>&2
	elif [ -d "$tmpdir/repository/doc" ]; then
		#generate documentation if available
		(cd "$tmpdir/repository" &&
			$CONFIGURE &&
			cd doc &&
			$MAKE DESTDIR="$tmpdir/destdir" install)|| ret=2
		#upload the documentation if relevant
		if [ $ret -eq 0 -a -d "$tmpdir/destdir$DATADIR/gtk-doc" ]; then
			$RSYNC "$tmpdir/destdir$DATADIR/gtk-doc" "$MIRROR" \
								|| ret=2
		fi
	fi
	#cleanup
	$RM -r "$tmpdir"
	return $ret
}


#usage
_usage()
{
	echo "Usage: $PROGNAME_GIT_DOC repository" 1>&2
	return 1
}


#main
if [ $# -ne 1 ]; then
	_usage
	exit $?
fi
_git_tests "$1"
