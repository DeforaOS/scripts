PREFIX	= /usr/local
DESTDIR	=
MKDIR	= mkdir -m 0755 -p
INSTALL	= install
RM	= rm -f


all:

clean:

distclean: clean

install:
	$(MKDIR) $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -m 0755 deforaos-build.sh $(DESTDIR)$(PREFIX)/bin/deforaos-build.sh
	$(MKDIR) $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -m 0755 deforaos-package.sh $(DESTDIR)$(PREFIX)/bin/deforaos-package.sh
	$(MKDIR) $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -m 0755 deforaos-release.sh $(DESTDIR)$(PREFIX)/bin/deforaos-release.sh
	$(MKDIR) $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -m 0755 deforaos-update.sh $(DESTDIR)$(PREFIX)/bin/deforaos-update.sh

uninstall:
	$(RM) -- $(DESTDIR)$(PREFIX)/bin/deforaos-build.sh
	$(RM) -- $(DESTDIR)$(PREFIX)/bin/deforaos-package.sh
	$(RM) -- $(DESTDIR)$(PREFIX)/bin/deforaos-release.sh
	$(RM) -- $(DESTDIR)$(PREFIX)/bin/deforaos-update.sh

.PHONY: all clean distclean install uninstall
