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
	$(INSTALL) -m 0755 deforaos-document.sh $(DESTDIR)$(PREFIX)/bin/deforaos-document.sh
	$(MKDIR) $(DESTDIR)$(PREFIX)/libexec
	$(INSTALL) -m 0755 deforaos-git-hook.sh $(DESTDIR)$(PREFIX)/libexec/deforaos-git-hook.sh
	$(MKDIR) $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -m 0755 deforaos-lock.sh $(DESTDIR)$(PREFIX)/bin/deforaos-lock.sh
	$(MKDIR) $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -m 0755 deforaos-package.sh $(DESTDIR)$(PREFIX)/bin/deforaos-package.sh
	$(MKDIR) $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -m 0755 deforaos-release.sh $(DESTDIR)$(PREFIX)/bin/deforaos-release.sh
	$(MKDIR) $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -m 0755 deforaos-update.sh $(DESTDIR)$(PREFIX)/bin/deforaos-update.sh

uninstall:
	$(RM) -- $(DESTDIR)$(PREFIX)/bin/deforaos-build.sh
	$(RM) -- $(DESTDIR)$(PREFIX)/bin/deforaos-document.sh
	$(RM) -- $(DESTDIR)$(PREFIX)/libexec/deforaos-git-hook.sh
	$(RM) -- $(DESTDIR)$(PREFIX)/bin/deforaos-lock.sh
	$(RM) -- $(DESTDIR)$(PREFIX)/bin/deforaos-package.sh
	$(RM) -- $(DESTDIR)$(PREFIX)/bin/deforaos-release.sh
	$(RM) -- $(DESTDIR)$(PREFIX)/bin/deforaos-update.sh

.PHONY: all clean distclean install uninstall
