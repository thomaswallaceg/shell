# Installs the shell, the greeter and the systemd user units as plain files
# under a prefix, following the usual GNU conventions:
#
#   sudo make install							# everything, under /usr/local
#   sudo make install-greeter               	# just one part (see help)
#   make install PREFIX=/usr DESTDIR=/tmp/stage
#	make										# prints help
#
# Layout under $(pkgdatadir) mirrors the repo: shell/, greeter/ and common/
# as siblings, which the shell/common and greeter/common symlinks rely on.

PKGNAME := thomas-shell
VERSION := 0.1.0

PREFIX     ?= /usr/local
DATADIR    ?= $(PREFIX)/share
DOCDIR     ?= $(DATADIR)/doc/$(PKGNAME)
# Distros differ on whether user units live under lib/ or lib64/; the usual
# override is `make SYSTEMDUSERUNITDIR=$(pkg-config --variable=systemduserunitdir systemd)`.
SYSTEMDUSERUNITDIR ?= $(PREFIX)/lib/systemd/user
# Read by the systemd user manager (/usr/local/lib and /usr/lib are both on
# its search path).
ENVIRONMENTDDIR ?= $(PREFIX)/lib/environment.d
# polkit only reads actions from here, whatever the PREFIX.
POLKITACTIONSDIR ?= /usr/share/polkit-1/actions
DESTDIR    ?=

pkgdatadir := $(DATADIR)/$(PKGNAME)

INSTALL ?= install

# Checked-in files that name the install location use the PREFIX=/usr one,
# /usr/share/thomas-shell; installed copies get the real path for the chosen
# prefix.
SUBST = sed -e 's|/usr/share/$(PKGNAME)|$(pkgdatadir)|g'

UNITS := systemd/thomas-shell.service
ENVFILE := systemd/environment.d/60-$(PKGNAME).conf
POLICY := polkit/io.github.thomaswallaceg.$(PKGNAME).policy

.PHONY: help install install-shell install-greeter install-units install-doc uninstall dist

help:
	@echo "Targets (PREFIX=$(PREFIX)):"
	@echo "  install          all of the install-* targets below"
	@echo "  install-shell    shell/ + common/  -> $(pkgdatadir),"
	@echo "                   QS_CONFIG_PATH    -> $(ENVIRONMENTDDIR)"
	@echo "                   polkit policy     -> $(POLKITACTIONSDIR)"
	@echo "  install-greeter  greeter/ + common/ -> $(pkgdatadir)"
	@echo "  install-units    systemd user units -> $(SYSTEMDUSERUNITDIR)"
	@echo "  install-doc      README + LICENSE   -> $(DOCDIR)"
	@echo "  uninstall        remove everything install puts there"
	@echo "  dist             write $(PKGNAME)-$(VERSION).tar.gz from the current git HEAD"

install: install-shell install-greeter install-units install-doc

# Replaces each tree under $(pkgdatadir) with a fresh copy (so files removed
# from the repo don't linger), keeping git's executable bits and the relative
# symlinks, and skipping local editor/Qt caches.
define install_trees
	@set -e; \
	for tree in $(1); do \
		rm -rf "$(DESTDIR)$(pkgdatadir)/$$tree"; \
		find "$$tree" -name .qmlls.ini -prune -o -name '*.qmlc' -prune -o -print | while read -r path; do \
			dest="$(DESTDIR)$(pkgdatadir)/$$path"; \
			if [ -L "$$path" ]; then \
				rm -f "$$dest"; ln -s "$$(readlink "$$path")" "$$dest"; \
			elif [ -d "$$path" ]; then \
				$(INSTALL) -d -m 755 "$$dest"; \
			elif [ -x "$$path" ]; then \
				$(INSTALL) -m 755 "$$path" "$$dest"; \
			else \
				$(INSTALL) -m 644 "$$path" "$$dest"; \
			fi; \
		done; \
	done
	@echo "Installed $(1) to $(DESTDIR)$(pkgdatadir)"
endef

install-shell:
	$(call install_trees,common shell)
	$(INSTALL) -d -m 755 "$(DESTDIR)$(ENVIRONMENTDDIR)"
	$(SUBST) $(ENVFILE) > "$(DESTDIR)$(ENVIRONMENTDDIR)/$(notdir $(ENVFILE))"
	chmod 644 "$(DESTDIR)$(ENVIRONMENTDDIR)/$(notdir $(ENVFILE))"
	$(INSTALL) -d -m 755 "$(DESTDIR)$(POLKITACTIONSDIR)"
	$(SUBST) $(POLICY) > "$(DESTDIR)$(POLKITACTIONSDIR)/$(notdir $(POLICY))"
	chmod 644 "$(DESTDIR)$(POLKITACTIONSDIR)/$(notdir $(POLICY))"

install-greeter:
	$(call install_trees,common greeter)
	$(SUBST) greeter/config.toml > "$(DESTDIR)$(pkgdatadir)/greeter/config.toml"

install-units:
	$(INSTALL) -d -m 755 "$(DESTDIR)$(SYSTEMDUSERUNITDIR)"
	@set -e; for unit in $(UNITS); do \
		$(SUBST) "$$unit" > "$(DESTDIR)$(SYSTEMDUSERUNITDIR)/$${unit##*/}"; \
		chmod 644 "$(DESTDIR)$(SYSTEMDUSERUNITDIR)/$${unit##*/}"; \
	done

install-doc:
	$(INSTALL) -d -m 755 "$(DESTDIR)$(DOCDIR)"
	$(INSTALL) -m 644 README.md LICENSE "$(DESTDIR)$(DOCDIR)/"

uninstall:
	rm -rf "$(DESTDIR)$(pkgdatadir)" "$(DESTDIR)$(DOCDIR)"
	rm -f "$(DESTDIR)$(ENVIRONMENTDDIR)/$(notdir $(ENVFILE))"
	rm -f "$(DESTDIR)$(POLKITACTIONSDIR)/$(notdir $(POLICY))"
	rm -f $(addprefix "$(DESTDIR)$(SYSTEMDUSERUNITDIR)/,$(addsuffix ",$(notdir $(UNITS))))

# Release tarball of the committed tree (uncommitted changes aren't included).
# callie is a submodule and git archive leaves it out: it's released on its
# own.
dist:
	git archive --format=tar.gz --prefix=$(PKGNAME)-$(VERSION)/ \
		-o $(PKGNAME)-$(VERSION).tar.gz HEAD
	@echo "Wrote $(PKGNAME)-$(VERSION).tar.gz"
