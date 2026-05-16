KA := https://github.com/ketchuphub/ketchup-action
KA-TAG ?= v1
K := .cache/ketchup-action-$(KA-TAG)
$(shell [ -d '$K' ] || git clone -q --branch $(KA-TAG) $(KA) '$K')

R := https://github.com/makeplus/makes
M := .cache/makes
$(shell [ -d '$M' ] || git clone -q $R '$M')

include $M/init.mk
include $K/ketchup.mk
include $M/shell.mk
include $M/clean.mk

MAKES-CLEAN := \
  www/docs/dates.json \
  www/docs/reports/ \

MAKES-REALCLEAN := \
  www/hooks/__pycache__/ \
  www/site/ \
  www/venv/ \

UTIL-TARGETS := \
  check-origin \
  sync-mkdocs \
  ensure-gh-pages \
  enable-pages \
  run \


serve publish:
	$(MAKE) -C www $@

update: check-origin sync-mkdocs push-secrets ensure-gh-pages enable-pages
	@util/make update-done

$(UTIL-TARGETS): $(GH) $(PERL)
	@util/make $@
