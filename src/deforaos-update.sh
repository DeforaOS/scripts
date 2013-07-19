#!/usr/bin/env sh
#$Id$
#Copyright (c) 2008-2013 Pierre Pronchery <khorben@defora.org>
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
umask 022
#variables
DATE=$(date '+%Y%m%d')
DESTDIR="/var/www"
DEVNULL="/dev/null"
EMAIL="devel@lists.defora.org"
HOMEPAGE="http://www.defora.org"
ROOT=
SRC=

#CVS
CVSMODULE="DeforaOS"
SRC="$HOME/$CVSMODULE"
[ -z "$CVSROOT" ] && CVSROOT=":pserver:anonymous@anoncvs.defora.org:/home/cvs"

#Git
[ -z "$GITROOT" ] && GITROOT="http://git.defora.org/git/DeforaOS.git"

#executables
CONFIGURE="configure"
CVS="cvs -q"
FIND="find"
GIT="git"
LN="ln -f"
MAIL="mail"
MAKE="make"
MKDIR="mkdir -m 0755 -p"
MKTEMP="mktemp"
RM="rm -f"
RMDIR="rmdir"
TAR="tar"
TOUCH="touch"
XARGS="xargs"


#functions
#deforaos_update_cvs
_deforaos_update_cvs()
{
	[ -n "$SRC" ] || SRC="$ROOT/$CVSMODULE"

	#configure cvs if necessary
	$MKDIR "$HOME"						|| exit 2
	if [ ! -f "$HOME/.cvspass" ]; then
		$TOUCH "$HOME/.cvspass"				|| exit 2
	fi

	#checkout tree if necessary
	if [ ! -d "$SRC" ]; then
		echo ""
		echo "Checking out CVS module $CVSMODULE:"
		(cd "$HOME" && $CVS "-d$CVSROOT" co "$CVSMODULE") \
								|| exit 2
	fi

	#update tree
	echo ""
	echo "Updating CVS module $CVSMODULE:"
	(cd "$SRC" && $CVS update -dPA)				|| exit 2

	#make archive
	echo ""
	echo "Archiving CVS module $CVSMODULE:"
	for i in *; do
		echo "DeforaOS-$DATE/$i"
	done | ($LN -s . "DeforaOS-$DATE" \
			&& $XARGS $TAR -czf "$DESTDIR/htdocs/download/snapshots/DeforaOS-daily.tar.gz")
	$RM "DeforaOS-$DATE"
	echo "$HOMEPAGE/download/snapshots/DeforaOS-daily.tar.gz"
}


#deforaos_update_git
_deforaos_update_git()
{
	SRC="DeforaOS.git"

	#checkout tree if necessary
	if [ ! -d "$SRC" ]; then
		echo ""
		echo "Checking out Git repository $SRC:"
		$GIT clone "$GITROOT" "$SRC" > "$DEVNULL"	|| exit 2
	fi

	#update tree
	echo ""
	echo "Updating Git repository $SRC:"
	(cd "$SRC" && $GIT checkout -f && $GIT pull > "$DEVNULL") \
								|| exit 2

	#re-generate the makefiles
	echo ""
	echo "Re-generating the Makefiles:"
	$CONFIGURE "$SRC/System/src" "$SRC/Apps" "$SRC/Library"	|| exit 2

	#update the sub-repositories
	echo ""
	echo "Updating the sub-repositories:"
	$FIND "$SRC" -name script.sh | while read script; do
		parent="${script%%/script.sh}"
		#XXX read project.conf instead
		for i in "$parent/"*; do
			[ -d "$i" ] || continue
			(cd "$i" && $MAKE download) > "$DEVNULL"
		done
	done

	#make archive
	echo ""
	echo "Archiving DeforaOS from Git repository $GITROOT:"
	for i in "$SRC/.git" "$SRC/"*; do
		i=${i##$SRC/}
		echo "DeforaOS-$DATE/$i"
	done | ($LN -s "$SRC" "DeforaOS-$DATE" \
			&& $XARGS $TAR -czf "$DESTDIR/htdocs/download/snapshots/DeforaOS-daily.tar.gz")
	$RM "DeforaOS-$DATE"
	echo "$HOMEPAGE/download/snapshots/DeforaOS-daily.tar.gz"
}


#usage
_usage()
{
	echo "Usage: deforaos-update.sh [-O name=value...]" 1>&2
	return 1
}


#main
#parse options
update=_deforaos_update_cvs
scm=
while getopts "CgO:" name; do
	case "$name" in
		C)
			scm="CVS"
			update=_deforaos_update_cvs
			;;
		g)
			scm="Git"
			update=_deforaos_update_git
			;;
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
if [ $# -ne 0 ]; then
	_usage
	exit $?
fi
[ -n "$ROOT" ] || ROOT=$($MKTEMP -d -p "$HOME" "temp.XXXXXX")
[ -n "$ROOT" ] || exit 2
$update 2>&1 | $MAIL -s "Daily $scm update: $DATE" "$EMAIL"
$RMDIR "$ROOT"
