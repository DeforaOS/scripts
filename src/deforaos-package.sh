#!/bin/sh
#$Id$
#Copyright (c) 2012-2015 Pierre Pronchery <khorben@defora.org>
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
DOMAIN="defora.org"
EMAIL=
FORCE=0
FULLNAME=
HOMEPAGE="http://www.$DOMAIN"
ID="@ID@"
LANG="C"
LICENSE=
METHOD=
PACKAGE=
PROJECTCONF="project.conf"
VERBOSE=0
VERSION=
#executables
CAT="cat"
CKSUM="cksum"
CONFIGURE="configure"
CP="cp"
CUT="cut"
DCH="dch"
DPKG="dpkg"
DPKG_BUILDPACKAGE="dpkg-buildpackage -rfakeroot"
DPKG_SOURCE="dpkg-source"
FIND="find"
GIT="git"
GREP="grep"
LINTIAN="lintian"
MAKE="make"
MKDIR="mkdir -p"
MV="mv"
PKGLINT="pkglint"
PREFIX="/usr/local"
RM="rm -f"
RMD160="rmd160"
SHA1="sha1"
SIZE="_size"
TOUCH="touch"
TR="tr"
WC="wc"
YEAR="$(date +%Y)"
#dependencies
DEPEND_desktop=0
DEPEND_docbookxsl=0
DEPEND_gtkdoc=0
DEPEND_pkgconfig=0
DEPEND_xgettext=0
#method-specific
DEBIAN_FILES="compat control copyright rules"
DEBIAN_MESSAGE="Package generated automatically by deforaos-package.sh"
DEBIAN_PREFIX="deforaos-"
PKGSRC_PREFIX="deforaos-"
PKGSRC_ROOT="/usr/pkgsrc"


#functions
#deforaos_package
_deforaos_package()
{
	revision="$1"

	_package_guess_name
	if [ $? -ne 0 ]; then
		_error "Could not determine the package name or version"
		return $?
	fi
	[ -n "$METHOD" ] || _package_guess_method
	[ -n "$LICENSE" ] || _package_guess_license
	_package_guess_dependencies
	[ -n "$EMAIL" ] || _package_guess_email
	[ -n "$FULLNAME" ] || _package_guess_fullname

	#call the proper packaging function
	case "$METHOD" in
		debian|pkgsrc)
			_info "Packaging for $METHOD"
			_package_$METHOD "$revision"
			[ $? -ne 0 ] && return 2
			;;
		*)
			_error "Unsupported packaging method"
			return $?
			;;
	esac

	_info "DeforaOS $PACKAGE $VERSION-$revision packaged"
}

_package_diff()
{
	if [ -d "CVS" ]; then
		_package_diff_cvs
		return $?
	elif [ -d ".git" ]; then
		_package_diff_git
		return $?
	else
		return 2
	fi
}

_package_diff_cvs()
{
	#XXX this method may be obsoleted in a future version of CVS
	$DEBUG $CVS diff > "$DEVNULL"
}

_package_diff_git()
{
	$DEBUG $GIT status > "$DEVNULL"
	$DEBUG $GIT diff --quiet
}

_package_guess_dependencies()
{
	#desktop database
	DEPEND_desktop=0
	for i in data/*.desktop; do
		[ ! -f "$i" ] && continue
		DEPEND_desktop=1
	done

	#docbook-xsl
	DEPEND_docbookxsl=0
	[ -f "doc/docbook.sh" ] && DEPEND_docbookxsl=1

	#gtk-doc
	DEPEND_gtkdoc=0
	[ -f "doc/gtkdoc.sh" ] && DEPEND_gtkdoc=1

	#pkg-config
	DEPEND_pkgconfig=0
	$GREP "\`pkg-config " "src/$PROJECTCONF" > "$DEVNULL" &&
		DEPEND_pkgconfig=1

	#xgettext
	DEPEND_xgettext=0
	[ -f "po/gettext.sh" ] && DEPEND_xgettext=1
}

_package_guess_email()
{
	[ -d ".git" ] && EMAIL=$($GIT config user.email)
	[ -n "$EMAIL" ] || EMAIL="$USER@$DOMAIN"
}

_package_guess_fullname()
{
	[ -d ".git" ] && FULLNAME=$($GIT config user.name)
	[ -n "$FULLNAME" ] || FULLNAME="$USER"
}

_package_guess_license()
{
	[ ! -f "COPYING" ]					&& return 2

	#guess the license
	sum=$($CKSUM COPYING)
	sum=${sum%% *}
	case "$sum" in
		199341746)
			LICENSE="GNU GPL 3"
			;;
	esac
}

_package_guess_method()
{
	#guess the packaging method
	METHOD=

	#debian
	[ -f "/etc/debian_version" ] && METHOD="debian"

	#pkgsrc
	[ -d "/usr/pkg" ] && METHOD="pkgsrc"

	if [ -z "$METHOD" ]; then
		_error "Unsupported platform"
		return $?
	fi
}

_package_guess_name()
{
	PACKAGE=
	VERSION=

	while read line; do
		case "$line" in
			"package="*)
				PACKAGE="${line#package=}"
				;;
			"version="*)
				VERSION="${line#version=}"
				;;
			"["*)
				break
				;;
		esac
	done < "$PROJECTCONF"
	[ -z "$PACKAGE" -o -z "$VERSION" ]			&& return 2
	return 0
}


#package_debian
_package_debian()
{
	pkgname=$(echo "$DEBIAN_PREFIX$PACKAGE" | $TR A-Z a-z)

	([ $FORCE -eq 0 ] || $DEBUG $RM -r -- ".pc" "debian")	|| return 2

	#check for changes
	_info "Checking for changes..."
	_package_diff
	if [ $? -ne 0 ]; then
		_error "The sources were modified"
		return $?
	fi

	#cleanup
	$DEBUG $MAKE distclean					|| return 2


	#initialization
	$DEBUG $MKDIR -- "debian" "debian/source"		|| return 2

	#create the source archive
	_info "Creating the source archive..."
	$DEBUG $MAKE dist
	if [ $? -ne 0 ]; then
		_error "Could not create the source archive"
		return 2
	fi
	$DEBUG $MV -- "$PACKAGE-$VERSION.tar.gz" \
		"../${pkgname}_$VERSION.orig.tar.gz"
	if [ $? -ne 0 ]; then
		_error "Could not move source archive"
		return 2
	fi

	#re-generate the Makefiles
	if [ -f "$PROJECTCONF" ]; then
		_info "Re-generating the Makefiles..."
		$DEBUG $CONFIGURE				|| return 2
	fi

	#check the license
	license=
	case "$LICENSE" in
		"GNU GPL 3")
			license="GPL-3"
			;;
	esac
	[ -n "$license" ] || _warning "Unknown license"

	#debian files
	[ $FORCE -eq 0 ] || for i in $DEBIAN_FILES; do
		_info "Creating debian/$i..."
		"_debian_$i" > "debian/$i"
		if [ $? -ne 0 ]; then
			$DEBUG $RM -r -- "debian"
			_error "Could not create debian/$i"
			return 2
		fi
	done

	#debian/changelog
	_info "Creating debian/changelog..."
	_debian_changelog
	if [ $? -ne 0 ]; then
		 [ $FORCE -eq 0 ] || $DEBUG $RM -r -- "debian"
		_error "Could not create debian/changelog"
		return 2
	fi

	#debian/install
	_debian_install

	#debian/menu
	_debian_menu

	#debian/source/format
	_debian_source_format > "debian/source/format"
	if [ $? -ne 0 ]; then
		 [ $FORCE -eq 0 ] || $DEBUG $RM -r -- "debian"
		_error "Could not create debian/source/format"
		return 2
	fi

	#register the changes if any
	$DEBUG $DPKG_SOURCE --commit . patch-Makefile
	res=$?
	if [ $res -eq 127 ]; then
		#XXX ignore errors if the command is not installed
		return 0
	elif [ $res -ne 0 ]; then
		return 2
	fi

	#build the package
	_info "Building the package..."
	$DEBUG $DPKG_BUILDPACKAGE
	#XXX ignore errors if the command is not installed
	if [ $? -eq 127 ]; then
		_warning "Could not build the package"
		return 0
	fi

	#check the package
	_debian_lintian
}

_debian_changelog()
{
	[ -n "$DEBFULLNAME" ] || DEBFULLNAME="$FULLNAME"
	[ -n "$DEBEMAIL" ] || DEBEMAIL="$EMAIL"
	create=
	[ -f "debian/changelog" ] || create="--create"

	DEBFULLNAME="$DEBFULLNAME" DEBEMAIL="$DEBEMAIL" $DEBUG $DCH $create \
		--distribution "unstable" \
		--package "$pkgname" --newversion "$VERSION-$revision" \
		"$DEBIAN_MESSAGE"
	ret=$?

	#XXX ignore errors if the command is not installed
	if [ $ret -eq 127 ]; then
		_warning "Could not create debian/changelog"
		return 0
	fi

	return $ret
}

_debian_compat()
{
	echo "9"
}

_debian_control()
{
	section="unknown"

	#library major
	major=
	if [ -z "${PACKAGE%%lib*}" ]; then
		major=0
		section="libs"
	fi

	#build dependencies
	depends="debhelper (>= 9)"
	[ $DEPEND_docbookxsl -eq 1 ] && depends="$depends, docbook-xsl"
	[ $DEPEND_xgettext -eq 1 ] && depends="$depends, gettext"
	[ $DEPEND_pkgconfig -eq 1 ] && depends="$depends, pkg-config"

	$CAT << EOF
Source: $pkgname
Section: $section
Priority: optional
Maintainer: $FULLNAME <$EMAIL>
Build-Depends: $depends
Standards-Version: 3.9.4
Homepage: $HOMEPAGE/os/project/$ID/$PACKAGE

Package: $pkgname$major
Architecture: any
Depends: \${shlibs:Depends}, \${misc:Depends}
Description: DeforaOS $PACKAGE
 DeforaOS $PACKAGE
EOF

	#also generate a development package if necessary
	[ -n "$major" ] || return 0
	$CAT << EOF

Package: $pkgname-dev
Section: libdevel
Architecture: any
Depends: $pkgname$major (= \${binary:Version})
Description: DeforaOS $PACKAGE (development files)
 DeforaOS $PACKAGE (development files)
EOF
}

_debian_copyright()
{
	$CAT << EOF
Format-Specification: http://svn.debian.org/wsvn/dep/web/deps/dep5.mdwn?op=file&rev=135
Name: $pkgname
Maintainer: $FULLNAME <$EMAIL>
Source: $HOMEPAGE/os/project/download/$ID

Copyright: $YEAR $FULLNAME <$EMAIL>
License: $license

Files: debian/*
Copyright: $YEAR $FULLNAME <$EMAIL>
License: $license
EOF
	case "$license" in
		GPL-3)
			$CAT << EOF

License: GPL-3
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, version 3 of the License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.
 .
 You should have received a copy of the GNU General Public License along
 with this program; if not, see <http://www.gnu.org/licenses/>.
 .
 On Debian systems, the full text of the GNU General Public
 License version 3 can be found in the file
 \`/usr/share/common-licenses/GPL-3'.
EOF
			;;
	esac
}

_debian_install()
{
	major=
	[ -z "${PACKAGE%%lib*}" ] && major=0

	[ -n "$major" ] || return 0

	#FIXME some files may be missed (or absent)
	$CAT > "debian/$pkgname$major.install" << EOF
usr/bin/*
usr/lib/lib*.so.$major
usr/lib/lib*.so.$major.*
usr/share/doc/*
usr/share/man/html1/*
usr/share/man/man1/*
EOF

	$CAT > "debian/$pkgname-dev.install" << EOF
usr/include/*
usr/lib/lib*.a
usr/lib/lib*.so
usr/lib/pkgconfig/*.pc
usr/share/gtk-doc/html/*
EOF
}

_debian_lintian()
{
	arch="$($DPKG --print-architecture)"
	major=
	[ -z "${PACKAGE%%lib*}" ] && major=0

	_info "Checking the package..."
	#XXX only check for the packages built this time
	for i in "../${pkgname}_$VERSION-${revision}_$arch.deb" \
		"../$pkgname${major}_$VERSION-${revision}_$arch.deb" \
		"../$pkgname-dev_$VERSION-${revision}_$arch.deb"; do
		[ -f "$i" ] || continue

		$DEBUG $LINTIAN "$i"
		#XXX ignore errors if the command is not installed
		if [ $? -eq 127 ]; then
			_warning "Could not check the package"
			return 0
		fi
	done
}

_debian_menu()
{
	#obtain the menu entries
	menus=
	for i in data/*.desktop; do
		[ ! -f "$i" ] && continue
		i="${i#data/}"
		i="${i%.desktop}"
		menus="$menus $i"
	done
	[ -z "$menus" ] && return 0

	#debian/menu
	_info "Creating debian/menu..."
	$TOUCH "debian/menu"					|| return 2
	for i in $menus; do
		section="Applications"
		title="$i"
		command="/usr/bin/$i"

		while read line; do
			name="${line%%=*}"
			value="${line#*=}"

			#determine the most essential values
			case "$name" in
				Categories)
					;;
				Exec)
					command="/usr/bin/$value"
					continue
					;;
				Name)
					title="$value"
					continue
					;;
				*)
					continue
					;;
			esac

			#determine the section
			case "$value" in
				*Accessibility*)
					section="Applications/Accessibility"
					;;
				*Player*)
					section="Applications/Video"
					;;
				*Audio*|*Mixer*)
					section="Applications/Sound"
					;;
				*ContactManagement*)
					section="Applications/Data Management"
					;;
				*Development*)
					section="Applications/Programming"
					;;
				*Documentation*)
					section="Help"
					;;
				*Email*|*Telephony*)
					section="Applications/Network/Communication"
					;;
				*FileManager*)
					section="Applications/File Management"
					;;
				*Viewer*)
					section="Applications/Viewers"
					;;
				*Office*)
					section="Applications/Office"
					;;
				*Settings*)
					section="Applications/System/Administration"
					;;
				*TextEditor*)
					section="Applications/Editors"
					;;
				*WebBrowser*)
					section="Applications/Network/Web Browsing"
					;;
			esac
		done < "data/$i.desktop"
		echo "?package($pkgname):needs=\"X11\" \\"
		echo "	section=\"$section\" \\"
		echo "	title=\"$title\" command=\"$command\""
	done >> "debian/menu"
}

_debian_rules()
{
	destdir="\$(PWD)/debian/$pkgname"

	[ -z "${PACKAGE%%lib*}" ] && destdir="\$(PWD)/debian/tmp"
	$CAT << EOF
#!/usr/bin/make -f

%:
	dh \$@
EOF
	[ -f "$PROJECTCONF" ] && $CAT << EOF

override_dh_auto_build:
	\$(MAKE) PREFIX="/usr"

override_dh_auto_clean:
	\$(MAKE) distclean

override_dh_auto_install:
	\$(MAKE) DESTDIR="$destdir" PREFIX="/usr" install
EOF
}

_debian_source_format()
{
	echo "3.0 (quilt)"
}


#package_pkgsrc
_package_pkgsrc()
{
	revision="$1"

	#the archive is needed
	_info "Checking the source archive..."
	if [ ! -f "$PACKAGE-$VERSION.tar.gz" ]; then
		_error "The source archive could not be found"
		_error "Have you ran deforaos-release.sh first?"
		return 2
	fi

	distname="$PACKAGE-$VERSION"
	pkgname=$(echo "$PKGSRC_PREFIX$PACKAGE" | $TR A-Z a-z)

	$DEBUG $RM -r -- "pkgname"				|| return 2
	$DEBUG $MKDIR -- "$pkgname"				|| return 2

	#check the license
	license=
	case "$LICENSE" in
		"GNU GPL 3")
			license="gnu-gpl-v3"
			;;
	esac
	[ -z "$license" ] && _warning "Unknown license"

	#DESCR
	_info "Creating $pkgname/DESCR..."
	_pkgsrc_descr > "$pkgname/DESCR"
	if [ $? -ne 0 ]; then
		$DEBUG $RM -r -- "$pkgname"
		_error "Could not create $pkgname/DESCR"
		return 2
	fi

	#Makefile
	_info "Creating $pkgname/Makefile..."
	_pkgsrc_makefile > "$pkgname/Makefile"
	if [ $? -ne 0 ]; then
		$DEBUG $RM -r -- "$pkgname"
		_error "Could not create $pkgname/Makefile"
		return 2
	fi

	#MESSAGE
	_info "Creating $pkgname/MESSAGE..."
	_pkgsrc_message "$pkgname"
	if [ $? -ne 0 ]; then
		$DEBUG $RM -r -- "$pkgname"
		_error "Could not create $pkgname/MESSAGE"
		return 2
	fi

	#PLIST
	_info "Creating $pkgname/PLIST..."
	tmpdir="$PWD/$pkgname/destdir"
	$MAKE DESTDIR="$tmpdir" PREFIX="$PREFIX" install
	if [ $? -ne 0 ]; then
		$RM -r -- "$pkgname"
		_error "Could not install files in staging directory"
		return 2
	fi
	echo "@comment \$NetBSD\$" > "$pkgname/PLIST"
	(cd "$tmpdir$PREFIX" && $FIND . -type f | $CUT -c 3- | sort) >> "$pkgname/PLIST"
	$RM -r -- "$tmpdir"

	#distinfo
	_info "Creating $pkgname/distinfo..."
	_pkgsrc_distinfo > "$pkgname/distinfo"
	if [ $? -ne 0 ]; then
		$RM -r -- "$pkgname"
		_error "Could not create $pkgname/distinfo"
		return 2
	fi

	#check the package
	_info "Running pkglint..."
	#XXX ignore errors for now
	(cd "$pkgname" && $DEBUG $PKGLINT)

	#FIXME:
	#- build the package
	#- review the differences (if any)
	#- commit
}

_pkgsrc_descr()
{
	if [ -f "$PKGSRC_ROOT/wip/$pkgname/DESCR" ]; then
		$CAT "$PKGSRC_ROOT/wip/$pkgname/DESCR"
		return $?
	fi
	echo "DeforaOS $PACKAGE"
}

_pkgsrc_distinfo()
{
	$CAT << EOF
\$NetBSD\$

EOF
	$SHA1 -- "$PACKAGE-$VERSION.tar.gz"
	$RMD160 -- "$PACKAGE-$VERSION.tar.gz"
	$SIZE -- "$PACKAGE-$VERSION.tar.gz"
	#additional patches
	for i in "$PKGSRC_ROOT/wip/$pkgname/patches/patch-"*; do
		[ ! -f "$i" ] && continue
		case "$i" in
			*.orig)
				continue
				;;
		esac
		i="${i##*/}"
		(cd "$PKGSRC_ROOT/wip/$pkgname/patches" && $SHA1 -- "$i") ||
			return 2
	done
}

_pkgsrc_makefile()
{
	$CAT << EOF
# \$NetBSD\$

DISTNAME=	$distname
EOF
	[ "$distname" != "$pkgname-$VERSION" ] && echo "PKGNAME=	$pkgname-$VERSION"
	[ $revision -gt 0 ] && $CAT << EOF
PKGREVISION=	$revision
EOF
	$CAT << EOF
CATEGORIES=	wip
MASTER_SITES=	$HOMEPAGE/os/download/download/$ID/

MAINTAINER=	$EMAIL
HOMEPAGE=	$HOMEPAGE/
COMMENT=	DeforaOS $PACKAGE
EOF

	#license
	[ -n "$license" ] && $CAT << EOF

LICENSE=	$license
EOF

	#tools
	tools=
	[ $DEPEND_pkgconfig -eq 1 ] && tools="$tools pkg-config"
	[ $DEPEND_xgettext -eq 1 ] && tools="$tools xgettext"
	[ -n "$tools" ] && echo
	for i in $tools; do
		echo "USE_TOOLS+=	$i"
	done

	#build dependencies
	#docbook
	[ $DEPEND_docbookxsl -eq 1 ] && $CAT << EOF

BUILD_DEPENDS+=	libxslt-[0-9]*:../../textproc/libxslt
BUILD_DEPENDS+=	docbook-xsl-[0-9]*:../../textproc/docbook-xsl
EOF

	$CAT << EOF

MAKE_FLAGS+=	DESTDIR=\${DESTDIR}
MAKE_FLAGS+=	PREFIX=\${PREFIX}
EOF

	#rc.d scripts
	rcd=
	for i in "$PKGSRC_ROOT/wip/$pkgname/files/"*.sh; do
		[ ! -f "$i" ] && continue
		i="${i##*/}"
		rcd="$rcd ${i%.sh}"
	done
	[ -n "$rcd" ] && echo
	for i in $rcd; do
		echo "RCD_SCRIPTS+=	$i"
	done

	#fix installation path for manual pages
	if [ $DEPEND_docbookxsl -eq 1 ]; then
		echo ""
		echo "post-install:"
		for i in doc/*.xml; do
			[ -f "$i" ] || continue
			page="${i#doc/}"
			page="${page%.xml}.1"
			echo "	\${MV} \${DESTDIR}\${PREFIX}/share/man/man1/$page \${DESTDIR}\${PREFIX}/\${PKGMANDIR}/man1/$page"
		done
		echo "	\${RMDIR} \${DESTDIR}\${PREFIX}/share/man/man1"
		echo "	\${RMDIR} \${DESTDIR}\${PREFIX}/share/man"
	fi

	#options
	[ -f "$PKGSRC_ROOT/wip/$pkgname/options.mk" ] && $CAT << EOF

.include "options.mk"
EOF

	#dependencies
	echo ""
	[ $DEPEND_gtkdoc -eq 1 ] &&
		echo '.include "../../textproc/gtk-doc/buildlink3.mk"'
	[ $DEPEND_desktop -eq 1 ] &&
		echo '.include "../../sysutils/desktop-file-utils/desktopdb.mk"'
	echo '.include "../../mk/bsd.pkg.mk"'
}

_pkgsrc_message()
{
	[ $# -eq 1 ]						|| return 1
	pkgname="$1"

	[ ! -f "$PKGSRC_ROOT/wip/$pkgname/MESSAGE" ]		&& return 0
	$DEBUG $CP -- "$PKGSRC_ROOT/wip/$pkgname/MESSAGE" "$pkgname/MESSAGE"
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
	echo "deforaos-package.sh: error: $@" 1>&2
	return 2
}


#info
_info()
{
	[ "$VERBOSE" -ne 0 ] && echo "deforaos-package.sh: $@" 1>&2
	return 0
}


#size
_size()
{
	while getopts "" name; do
		:
	done
	shift $((OPTIND - 1))
	[ $# -ne 1 ]						&& return 2
	size=$($WC -c "$1")
	for i in $size; do
		size="$i"
		break
	done
	echo "Size ($1) = $size bytes"
}


#usage
_usage()
{
	echo "Usage: deforaos-package.sh [-Dfv][-e e-mail][-i id][-l license][-m method][-n name][-O name=value...] revision" 1>&2
	echo "  -D	Run in debugging mode" 1>&2
	echo "  -f	Reset the packaging information" 1>&2
	echo "  -v	Verbose mode" 1>&2
	return 1
}


#warning
_warning()
{
	echo "deforaos-package.sh: warning: $@" 1>&2
}


#main
#parse options
while getopts "De:fi:l:m:n:O:v" name; do
	case "$name" in
		D)
			DEBUG="_debug"
			;;
		e)
			EMAIL="$OPTARG"
			;;
		f)
			FORCE=1
			;;
		i)
			ID="$OPTARG"
			;;
		l)
			LICENSE="$OPTARG"
			;;
		m)
			METHOD="$OPTARG"
			;;
		n)
			FULLNAME="$OPTARG"
			;;
		O)
			export "${OPTARG%%=*}"="${OPTARG#*=}"
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
if [ $# -ne 1 ]; then
	_usage
	exit $?
fi
revision="$1"

_deforaos_package "$revision"
