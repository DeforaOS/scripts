#!/usr/bin/env sh
#$Id$
#Copyright (c) 2012-2013 Pierre Pronchery <khorben@defora.org>
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
EMAIL="webmaster@defora.org"
HOMEPAGE="http://www.defora.org"
ROOT=
SRC=

#CVS
CVSMODULE="DeforaOS"
[ -z "$CVSROOT" ] && CVSROOT=":pserver:anonymous@anoncvs.defora.org:/home/cvs"

#Git
[ -z "$GITROOT" ] && GITROOT="http://git.defora.org/git/DeforaOS.git"

#executables
CONFIGURE="configure"
CVS="cvs -q"
FIND="find"
GIT="git"
INSTALL="install -m 0644"
LN="ln -f"
MAIL="mail"
MAKE="make"
MKDIR="mkdir -m 0755 -p"
MKTEMP="mktemp"
RM="rm -f"
TAR="tar"
TOUCH="touch"


#functions
#deforaos_document_cvs
_deforaos_document_cvs()
{
	[ -n "$SRC" ] || SRC="$ROOT/$CVSMODULE"

	#configure cvs if necessary
	$MKDIR -- "$HOME"					|| exit 2
	if [ ! -f "$HOME/.cvspass" ]; then
		$TOUCH "$HOME/.cvspass"				|| exit 2
	fi

	#checkout tree if necessary
	if [ ! -d "$SRC" ]; then
		$MKDIR -- "$ROOT"				|| exit 2
		echo ""
		echo "Checking out CVS module $CVSMODULE:"
		(cd "$ROOT" && $CVS "-d$CVSROOT" co "$CVSMODULE") > "$DEVNULL" \
								|| exit 2
	fi

	#update tree
	echo ""
	echo "Updating CVS module $CVSMODULE:"
	(cd "$SRC" && $CVS update -dPA) > "$DEVNULL"		|| exit 2

	#document tree
	echo ""
	echo "Documenting CVS module $CVSMODULE:"

	#manual pages
	echo ""
	echo " * manual pages"
	(cd "$SRC/Data/Documentation/DeforaOS Manual Pages" &&
		$MAKE &&
		$MKDIR -- "$DESTDIR/htdocs/doc/manual" &&
		$FIND "doc/manual" -name "*.html" -exec \
			$INSTALL -- {} "$DESTDIR/htdocs/{}" \;)
	echo "   $HOMEPAGE/doc/manual"

	#generic documentation
	echo ""
	echo " * generic documentation"
	$FIND "$SRC/System" "$SRC/Apps" -name "doc" | while read path; do
		[ -x "$path/docbook.sh" -o -x "$path/gtkdoc.sh" ] || continue
		(cd "$path" && $MAKE DESTDIR="$DESTDIR" PREFIX="/" \
				install > "$DEVNULL")
	done
	echo "   $HOMEPAGE/doc/gtk-doc/html"
}


#deforaos_document_git
_deforaos_document_git()
{
	SRC="DeforaOS.git"

	#checkout tree if necessary
	if [ ! -d "$ROOT/$SRC" ]; then
		$MKDIR -- "$ROOT"				|| exit 2
		echo ""
		echo "Checking out Git repository $SRC:"
		$GIT clone "$GITROOT" "$ROOT/$SRC" > "$DEVNULL"	|| exit 2
	fi

	#update tree
	echo ""
	echo "Updating Git repository $SRC:"
	(cd "$ROOT/$SRC" && $GIT checkout -f && $GIT pull) > "$DEVNULL" \
								|| exit 2

	#re-generate makefiles
	echo ""
	echo "Re-generating the Makefiles:"
	$CONFIGURE "$ROOT/$SRC/System/src" "$ROOT/$SRC/Apps" \
		"$ROOT/$SRC/Library"				|| exit 2

	#update the sub-repositories
	echo ""
	echo "Updating the sub-repositories:"
	$FIND "$ROOT/$SRC" -name script.sh | while read script; do
		parent="${script%%/script.sh}"
		#XXX read project.conf instead
		for i in "$parent/"*; do
			[ -f "$i/Makefile" ] || continue
			(cd "$i" && $MAKE download) > "$DEVNULL"
		done
	done

	#document tree
	echo ""
	echo "Documenting Git repository $SRC:"

	#manual pages
	echo ""
	echo " * manual pages"
	(cd "$ROOT/$SRC/Library/Documentation/src/DeforaOS Manual Pages" &&
		$MAKE &&
		$MKDIR -- "$DESTDIR/htdocs/doc/manual" &&
		$FIND "doc/manual" -name "*.html" -exec \
			$INSTALL -- {} "$DESTDIR/htdocs/{}" \;)
	echo "   $HOMEPAGE/doc/manual"

	#generic documentation
	echo ""
	echo " * generic documentation"
	$FIND "$ROOT/$SRC/System" "$ROOT/$SRC/Apps" -name "doc" | while read path; do
		[ -x "$path/docbook.sh" -o -x "$path/gtkdoc.sh" ] || continue
		(cd "$path" && $MAKE DESTDIR="$DESTDIR" PREFIX="/" \
				install > "$DEVNULL")
	done
	echo "   $HOMEPAGE/doc/gtk-doc/html"
}


#usage
_usage()
{
	echo "Usage: deforaos-document.sh [-C | -G][-O name=value...]" 1>&2
	return 1
}


#main
delete=0
#parse options
document=_deforaos_document_cvs
scm="CVS"
while getopts "CGO:" name; do
	case "$name" in
		C)
			document=_deforaos_document_cvs
			scm="CVS"
			;;
		G)
			document=_deforaos_document_git
			scm="Git"
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
if [ -z "$ROOT" ]; then
	ROOT=$($MKTEMP -d -p "$HOME" "temp.XXXXXX")
	delete=1
fi
[ -n "$ROOT" ] || exit 2
$document 2>&1 | $MAIL -s "Daily $scm documentation: $DATE" "$EMAIL"
[ $delete -eq 1 ] && $RM -r "$ROOT"
