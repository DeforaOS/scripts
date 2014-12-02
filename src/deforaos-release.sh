#!/bin/sh
#$Id$
#Copyright (c) 2012-2014 Pierre Pronchery <khorben@defora.org>
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
DEBUG=
DEVNULL="/dev/null"
DRYRUN=0
FREECODE="https://freecode.com/users/$USERNAME"
GIT_BRANCH="master"
HOMEPAGE="https://www.defora.org"
PACKAGE=
PROGNAME="deforaos-release.sh"
PROJECTCONF="project.conf"
VENDOR="deforaos"
VERBOSE=0
VERSION=
#executables
CONFIGURE="configure"
CVS="cvs"
GIT="git"
GREP="grep"
MAKE="make"
RM="rm -f"
TAR="tar"
TR="tr"
WC="wc"


#functions
#deforaos_release
_deforaos_release()
{
	version="$1"

	while read line; do
		case "$line" in
			"package="*)
				PACKAGE="${line#package=}"
				;;
			"version="*)
				VERSION="${line#version=}"
				;;
		esac
	done < "$PROJECTCONF"
	if [ -z "$PACKAGE" -o -z "$VERSION" ]; then
		_error "Could not determine the package name or version"
		return $?
	fi
	_info "Releasing $PACKAGE $VERSION"

	if [ "$version" != "$VERSION" ]; then
		_error "The version does not match"
		return $?
	fi

	_info "Obtaining latest version..."
	_release_fetch
	if [ $? -ne 0 ]; then
		_error "Could not update the sources"
		return $?
	fi

	#checking the desktop files
	for i in data/*.desktop; do
		[ ! -e "$i" ] && break
		basename="${i#data/}"
		if [ "$basename" = "${basename#$VENDOR-}" ]; then
			_error "data/$basename has no vendor prefix"
			return $?
		fi
	done

	if [ -f "po/$PACKAGE.pot" ]; then
		_info "Checking the translations..."
		$RM -- "po/$PACKAGE.pot"			|| return 2
		(cd "po" && $MAKE)				|| return 2
		$GREP -q "fuzzy" -- po/*.po
		if [ $? -eq 0 ]; then
			_error "Some translations are fuzzy"
			return $?
		fi
	fi

	#run configure again
	_release_configure

	_info "Checking for differences..."
	_release_diff
	if [ $? -ne 0 ]; then
		_error "The sources were modified"
		return $?
	fi

	_info "Creating the archive..."
	$DEBUG $MAKE distcheck
	if [ $? -ne 0 ]; then
		_error "Could not create the archive"
		return $?
	fi

	#tagging the release
	tag="${PACKAGE}_$(echo "$version" | $TR . -)"
	_info "Tagging the sources as $tag..."
	_release_tag "$tag"
	if [ $? -ne 0 ]; then
		_error "Could not tag the sources"
		return $?
	fi

	#all tests passed
	_info "$archive is ready for release"
	_info "The following steps are:"
	_info " * upload to $HOMEPAGE/os/project/submit/@ID@/$PACKAGE?type=release"
	_info " * publish a news on $HOMEPAGE/os/news/submit"
	_info " * post on $FREECODE"
	_info " * tweet (possibly via freecode)"
	_info " * package where appropriate (see deforaos-package.sh)"
}

_release_configure()
{
	if [ -f "$PROJECTCONF" ]; then
		$DEBUG $CONFIGURE
		return $?
	fi
	return 0
}

_release_diff()
{
	if [ -d "CVS" ]; then
		_release_diff_cvs
		return $?
	elif [ -d ".git" ]; then
		_release_diff_git
		return $?
	else
		return 2
	fi
}

_release_diff_cvs()
{
	#XXX this method may be obsoleted in a future version of CVS
	$DEBUG $CVS diff > "$DEVNULL"
}

_release_diff_git()
{
	$DEBUG $GIT diff --quiet
}

_release_fetch()
{
	if [ -d "CVS" ]; then
		_release_fetch_cvs
		return $?
	elif [ -d ".git" ]; then
		_release_fetch_git
		return $?
	else
		return 2
	fi
}

_release_fetch_cvs()
{
	$DEBUG $CVS up -A
}

_release_fetch_git()
{
	if [ -n "$GIT_BRANCH" ]; then
		$DEBUG $GIT checkout "$GIT_BRANCH"		|| return 2
	fi
	$DEBUG $GIT pull
}

_release_tag()
{
	tag="$1"

	if [ $DRYRUN -ne 0 ]; then
		return 0
	elif [ -d "CVS" ]; then
		_release_tag_cvs "$tag"
		return $?
	elif [ -d ".git" ]; then
		_release_tag_git "$tag"
		return $?
	fi
	return 2
}

_release_tag_cvs()
{
	tag="$1"

	$DEBUG $CVS tag "$tag"
}

_release_tag_git()
{
	tag="$1"

	$DEBUG $GIT tag -m "$PACKAGE $VERSION" "$tag"		|| return 2
	$DEBUG $GIT push --tags					|| return 2
}


#debug
_debug()
{
	echo "$@" 1>&2
	"$@"
}


#error
_error()
{
	echo "$PROGNAME: error: $@" 1>&2
	return 2
}


#info
_info()
{
	[ "$VERBOSE" -ne 0 ] && echo "$PROGNAME: $@" 1>&2
	return 0
}


#usage
_usage()
{
	echo "Usage: $PROGNAME [-Dnv][-O name=value...] version" 1>&2
	echo "  -D	Run in debugging mode" 1>&2
	echo "  -n	Do not actually publish changes (dry-run)" 1>&2
	echo "  -v	Verbose mode" 1>&2
	return 1
}


#main
#parse options
while getopts "DnvO:" name; do
	case "$name" in
		D)
			DEBUG="_debug"
			;;
		O)
			export "${OPTARG%%=*}"="${OPTARG#*=}"
			;;
		n)
			DRYRUN=1
			;;
		v)
			VERBOSE=1
			;;
		?)
			_usage
			exit $?
			;;
	esac
done
shift $((OPTIND - 1))
#parse arguments
if [ $# -ne 1 ]; then
	_usage
	exit $?
fi
version="$1"

_deforaos_release "$version"
