#!/bin/sh
#$Id$
#Copyright (c) 2012-2016 Pierre Pronchery <khorben@defora.org>
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
PROGNAME="deforaos-package.sh"
PROJECTCONF="project.conf"
VENDOR="DeforaOS"
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
MKTEMP="mktemp"
MV="mv"
PKGLINT="pkglint"
PREFIX=
RM="rm -f"
RMDIR="rmdir"
RMD160="rmd160"
SHA1="sha1"
SIZE="_size"
SORT="sort"
TAR="tar"
TOUCH="touch"
TR="tr"
UNIQ="uniq"
WC="wc"
XMLLINT="xmllint"
YEAR="$(date +%Y)"
#dependencies
DEPEND_desktop=0
DEPEND_docbookxsl=0
DEPEND_gtkdoc=0
DEPEND_pkgconfig=0
DEPEND_xgettext=0
#method-specific
DEBIAN_FILES="compat control copyright rules"
DEBIAN_MESSAGE="Package generated automatically by $PROGNAME"
DEBIAN_PREFIX=
PKGSRC_CATEGORY="wip"
PKGSRC_PREFIX=
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
	[ -n "$METHOD" ] || METHOD=$(_package_guess_method)
	[ -n "$LICENSE" ] || _package_guess_license
	_package_guess_dependencies
	[ -n "$EMAIL" ] || EMAIL=$(_package_guess_email)
	[ -n "$FULLNAME" ] || FULLNAME=$(_package_guess_fullname)

	#call the proper packaging function
	if [ -z "$METHOD" ]; then
		_error "Unknown packaging method"
		return $?
	fi
	_info "Packaging for $METHOD"
	"_package_$METHOD" "$revision"
	res=$?
	if [ $res -eq 127 ]; then
		_error "$METHOD: Unsupported packaging method"
		return $?
	elif [ $res -ne 0 ]; then
		return 2
	fi

	_info "$VENDOR $PACKAGE $VERSION-$revision packaged"
}

_package_diff()
{
	scm=$(_package_guess_scm)

	case "$scm" in
		cvs|git)
			"_package_diff_$scm"
			if [ $? -ne 0 ]; then
				_error "The sources were modified"
				return $?
			fi
			;;
		*)
			_warning "Could not check for source changes"
			;;
	esac
	return 0
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

_package_dist()
{
	$DEBUG $MAKE PACKAGE="$PACKAGE" dist
	if [ $? -ne 0 ]; then
		_error "Could not create the source archive"
		return 2
	fi
	return 0
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
	scm=$(_package_guess_scm)

	case "$scm" in
		git)
			$GIT config user.email			|| return 2
			return 0
			;;
	esac
	if [ -n "$EMAIL" ]; then
		echo "$EMAIL"
	else
		echo "$USER@$DOMAIN"
	fi
}

_package_guess_fullname()
{
	scm=$(_package_guess_scm)

	case "$scm" in
		git)
			$GIT config user.name			|| return 2
			return 0
			;;
	esac
	if [ -n "$FULLNAME" ]; then
		echo "$FULLNAME"
	else
		echo "$USER"
	fi
}

_package_guess_license()
{
	[ -f "COPYING" ]					|| return 2

	#guess the license
	sum=$($CKSUM COPYING)
	sum=${sum%% *}
	case "$sum" in
		199341746)
			LICENSE="GNU GPL 3"
			;;
		3336459709)
			LICENSE="GNU LGPL 3"
			;;
		*)
			return 2
			;;
	esac
	echo "$LICENSE"
	return 0
}

_package_guess_method()
{
	if [ -f "/etc/debian_version" ]; then
		#debian
		echo "debian"
	elif [ -d "/usr/pkg" ]; then
		#pkgsrc
		echo "pkgsrc"
	else
		#tarball
		echo "tarball"
	fi
	return 0
}

_package_guess_name()
{
	while read line; do
		case "$line" in
			"package="*)
				[ -n "$PACKAGE" ] || PACKAGE="${line#package=}"
				;;
			"version="*)
				[ -n "$VERSION" ] || VERSION="${line#version=}"
				;;
			"["*)
				break
				;;
		esac
	done < "$PROJECTCONF"
	[ -n "$PACKAGE" -a -n "$VERSION" ]			|| return 2
	return 0
}


#package_guess_scm
_package_guess_scm()
{
	if [ -d "CVS" ]; then
		#cvs
		echo "cvs"
	elif [ -d ".git" ]; then
		#git
		#FIXME also look in parent folders
		echo "git"
	else
		return 2
	fi
	return 0
}


#package_debian
_package_debian()
{
	[ -n "$DEBIAN_PREFIX" -o -z "$VENDOR" ] \
		|| DEBIAN_PREFIX=$(echo "$VENDOR-" | $TR A-Z a-z)
	pkgname=$(echo "$DEBIAN_PREFIX$PACKAGE" | $TR A-Z a-z)
	[ -n "$PREFIX" ] || PREFIX="/usr"

	#check for changes
	_info "Checking for changes..."
	_package_diff						|| return 2

	#cleanup
	$DEBUG $MAKE distclean					|| return 2

	#create the source archive
	_info "Creating the source archive..."
	if [ ! -f "../${pkgname}_${VERSION}.orig.tar.gz" ]; then
		_package_dist					|| return 2
		$DEBUG $MV -- "$PACKAGE-${VERSION}.tar.gz" \
			"../${pkgname}_${VERSION}.orig.tar.gz"
		if [ $? -ne 0 ]; then
			_error "Could not move source archive"
			return 2
		fi
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
	if [ $FORCE -ne 0 ]; then
		$DEBUG $RM -- ".pc"				|| return 2
		$DEBUG $RM -r -- "debian"			|| return 2
	fi
	[ -d "debian" ] || for i in $DEBIAN_FILES; do
		_info "Creating debian/$i..."
		$DEBUG $MKDIR -- "debian"			|| return 2
		"_debian_file_$i" > "debian/$i"
		if [ $? -ne 0 ]; then
			_error "Could not create debian/$i"
			return 2
		fi
	done

	#debian/changelog
	_info "Creating debian/changelog..."
	_debian_file_changelog
	if [ $? -ne 0 ]; then
		_error "Could not create debian/changelog"
		return 2
	fi

	#debian/install
	_debian_file_install					|| return 2

	#debian/menu
	_debian_file_menu					|| return 2

	#debian/source/format
	$DEBUG $MKDIR -- "debian/source"			|| return 2
	_debian_file_source_format > "debian/source/format"
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
	#XXX ugly workaround
	PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" $DEBUG $DPKG_BUILDPACKAGE
	#XXX ignore errors if the command is not installed
	if [ $? -eq 127 ]; then
		_warning "Could not build the package"
		return 0
	fi

	#check the package
	_debian_lintian
}

_debian_file_changelog()
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

_debian_file_compat()
{
	echo "9"
}

_debian_file_control()
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
Description: $VENDOR $PACKAGE
 $VENDOR $PACKAGE
EOF

	#also generate a development package if necessary
	[ -n "$major" ] || return 0
	$CAT << EOF

Package: $pkgname-dev
Section: libdevel
Architecture: any
Depends: $pkgname$major (= \${binary:Version})
Description: $VENDOR $PACKAGE (development files)
 $VENDOR $PACKAGE (development files)
EOF
}

_debian_file_copyright()
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

_debian_file_install()
{
	major=
	[ -z "${PACKAGE%%lib*}" ] && major=0

	[ -n "$major" ] || return 0

	#FIXME some files may be missed (or absent)
	if [ $FORCE -ne 0 -o ! -f "debian/$pkgname${major}.install" ]; then
		$CAT > "debian/$pkgname${major}.install" << EOF
usr/bin/*
usr/lib/lib*.so.$major
usr/lib/lib*.so.$major.*
usr/share/doc/*
usr/share/man/html1/*
usr/share/man/man1/*
EOF
	fi

	if [ $FORCE -ne 0 -o ! -f "debian/$pkgname-dev.install" ]; then
		$CAT > "debian/$pkgname-dev.install" << EOF
usr/include/*
usr/lib/lib*.a
usr/lib/lib*.so
usr/lib/pkgconfig/*.pc
usr/share/gtk-doc/html/*
EOF
	fi
}

_debian_file_menu()
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
	[ $FORCE -eq 0 -a -f "debian/menu" ]			&& return 0
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

_debian_file_rules()
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

_debian_file_source_format()
{
	echo "3.0 (quilt)"
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


#package_pkgsrc
_package_pkgsrc()
{
	revision="$1"
	[ -n "$PREFIX" ] || PREFIX="/usr/pkg"
	[ -n "$PKGSRC_PREFIX" -o -z "$VENDOR" ] \
		|| PKGSRC_PREFIX=$(echo "$VENDOR-" | $TR A-Z a-z)

	#create the source archive
	_info "Creating the source archive..."
	if [ ! -f "$PACKAGE-${VERSION}.tar.gz" ]; then
		_package_dist					|| return 2
	fi

	distname="$PACKAGE-$VERSION"
	pkgname=$(echo "$PKGSRC_PREFIX$PACKAGE" | $TR A-Z a-z)

	[ $FORCE -eq 0 ] || $DEBUG $RM -r -- "$pkgname"		|| return 2
	$DEBUG $MKDIR -- "$pkgname"				|| return 2

	#check the license
	license=
	case "$LICENSE" in
		"GNU GPL 3")
			license="gnu-gpl-v3"
			;;
		"GNU LGPL 3")
			license="gnu-lgpl-v3"
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

	return 0
}

_pkgsrc_descr()
{
	if [ -f "$PKGSRC_ROOT/$PKGSRC_CATEGORY/$pkgname/DESCR" ]; then
		$CAT "$PKGSRC_ROOT/$PKGSRC_CATEGORY/$pkgname/DESCR"
		return $?
	fi
	echo "$VENDOR $PACKAGE"
}

_pkgsrc_distinfo()
{
	$CAT << EOF
\$NetBSD\$

EOF
	$SHA1 -- "$PACKAGE-${VERSION}.tar.gz"
	$RMD160 -- "$PACKAGE-${VERSION}.tar.gz"
	$SIZE -- "$PACKAGE-${VERSION}.tar.gz"
	#additional patches
	for i in "$PKGSRC_ROOT/$PKGSRC_CATEGORY/$pkgname/patches/patch-"*; do
		[ ! -f "$i" ] && continue
		case "$i" in
			*.orig)
				continue
				;;
		esac
		i="${i##*/}"
		(cd "$PKGSRC_ROOT/$PKGSRC_CATEGORY/$pkgname/patches" \
			&& $SHA1 -- "$i")			|| return 2
	done
}

_pkgsrc_makefile()
{
	xpath="string(/refentry/refmeta/manvolnum)"
	sections=

	$CAT << EOF
# \$NetBSD\$

DISTNAME=	$distname
EOF
	[ "$distname" != "$pkgname-$VERSION" ] \
		&& echo "PKGNAME=	$pkgname-$VERSION"
	[ $revision -gt 0 ] && $CAT << EOF
PKGREVISION=	$revision
EOF
	$CAT << EOF
CATEGORIES=	$PKGSRC_CATEGORY
MASTER_SITES=	$HOMEPAGE/os/download/download/$ID/

MAINTAINER=	$EMAIL
HOMEPAGE=	$HOMEPAGE/
COMMENT=	$VENDOR $PACKAGE
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
	for i in "$PKGSRC_ROOT/$PKGSRC_CATEGORY/$pkgname/files/"*.sh; do
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
		echo ".include \"../../mk/bsd.prefs.mk\""
		echo ""
		echo ".if \${PKGMANDIR} != \"share/man\""
		echo "post-install:"
		#HTML pages
		for i in doc/*.xml; do
			[ -f "$i" ] || continue
			[ "${i%.css.xml}" = "$i" ] || continue
			section=$($XMLLINT --xpath "$xpath" "$i")
			[ -n "$section" ] || section="1"
			page="${i#doc/}"
			page="${page%.xml}.html"
			echo "	\${MV} \${DESTDIR}\${PREFIX}/share/man/html$section/$page \${DESTDIR}\${PREFIX}/\${PKGMANDIR}/html$section/$page"
		done | $SORT
		#manual pages
		for i in doc/*.xml; do
			[ -f "$i" ] || continue
			[ "${i%.css.xml}" = "$i" ] || continue
			section=$($XMLLINT --xpath "$xpath" "$i")
			[ -n "$section" ] || section="1"
			page="${i#doc/}"
			page="${page%.xml}.1"
			echo "	\${MV} \${DESTDIR}\${PREFIX}/share/man/man$section/$page \${DESTDIR}\${PREFIX}/\${PKGMANDIR}/man$section/$page"
		done | $SORT
		#remove directories
		for i in doc/*.xml; do
			[ -f "$i" ] || continue
			[ "${i%.css.xml}" = "$i" ] || continue
			section=$($XMLLINT --xpath "$xpath" "$i")
			[ -n "$section" ] || section="1"
			sections="$sections $section"
		done
		for section in $sections; do
			echo "	\${RMDIR} \${DESTDIR}\${PREFIX}/share/man/html$section"
			echo "	\${RMDIR} \${DESTDIR}\${PREFIX}/share/man/man$section"
		done | $SORT | $UNIQ
		echo "	\${RMDIR} \${DESTDIR}\${PREFIX}/share/man"
		echo ".endif"
	fi

	#options
	[ -f "$PKGSRC_ROOT/$PKGSRC_CATEGORY/$pkgname/options.mk" ] \
		&& $CAT << EOF

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

	[ ! -f "$PKGSRC_ROOT/$PKGSRC_CATEGORY/$pkgname/MESSAGE" ] \
		&& return 0
	$DEBUG $CP -- "$PKGSRC_ROOT/$PKGSRC_CATEGORY/$pkgname/MESSAGE" \
		"$pkgname/MESSAGE"
}


#package_tarball
_package_tarball()
{
	ret=0
	revision="$1"
	destdir="$($MKTEMP -d)/$PACKAGE-${VERSION}-$revision"
	[ $? -eq 0 ]						|| ret=2
	objdir="$($MKTEMP -d)/"
	[ $? -eq 0 ]						|| ret=2
	archive="$PWD/$PACKAGE-$VERSION-${revision}.tar.gz"

	if [ $ret -ne 0 ]; then
		[ -n "$destdir" ] && $RMDIR -- "$destdir" "${destdir%/*}"
		[ -n "$objdir" ] && $RMDIR -- "${objdir%/}"
		return $ret
	fi
	#FIXME also use OBJDIR="$objdir"
	$MAKE DESTDIR="$destdir" "install" &&
		(cd "${destdir%/*}" &&
		$TAR -czf "$archive" "$PACKAGE-${VERSION}-$revision")
	if [ $? -ne 0 ]; then
		$RM -r -- "${destdir%/*}" "${objdir%/}" "$archive"
		return 2
	fi
	return 0
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
	echo "Usage: $PROGNAME [-Dfv][-e e-mail][-i id][-l license][-m method][-n name][-O name=value...] revision" 1>&2
	echo "  -D	Run in debugging mode" 1>&2
	echo "  -f	Reset the packaging information" 1>&2
	echo "  -v	Verbose mode" 1>&2
	return 1
}


#warning
_warning()
{
	echo "$PROGNAME: warning: $@" 1>&2
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
