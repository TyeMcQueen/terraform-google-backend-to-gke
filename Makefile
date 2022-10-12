SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
# Mac's gnu Make 3.81 does not support .ONESHELL:
# .ONESHELL:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# COLORS
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

.PHONY: help
## Explain available make targets
help:
	@echo ''
	@echo 'Usage:'
	@echo '  $(YELLOW)make$(RESET) $(GREEN)<target>$(RESET)'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-_\/0-9.]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			odd = substr(" ", 0, 1-length(odd)); \
			printf "  $(YELLOW)%-15s $(GREEN)%s$(RESET)%s\n", \
				helpCommand, helpMessage, odd; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST) \
		| sed -e '/[^ ]$$/s/   / . /g' -e 's/ $$//'

## Update list of input variables in README.md
README.md.new: variables.tf README.md
	@( sed -n '1,/^## Input Variables/p' README.md; \
	  echo; grep -n '^variable ' < variables.tf \
		| sed -e 's/:variable  *"/:/' -e 's/".*//' -e \
		's!^\(.*\):\(.*\)!* [\2](/variables.tf#L\1)!' | sort \
	) > README.md.new
	@if  ! diff -q README.md README.md.new >/dev/null;  then \
		echo "Updating list of input variables in README.md..."; \
		run-cmd cp README.md.new README.md; \
		run-cmd touch README.md.new; \
	else \
		echo "(List of input variables in README.md already up-to-date.)"; \
	fi
