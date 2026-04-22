TAILWIND_DIR=./config/front
TAILWIND_INPUT=$(TAILWIND_DIR)/tailwind.input.css
TAILWIND_CONFIG=$(TAILWIND_DIR)/tailwind.config.js
TAILWIND_OUTPUT=./static/css/tailwind.css
FRONTEND_DIR=./frontend
PORT ?= 3700
APPROOT ?= http://localhost:$(PORT)
APP_ENV = PORT=$(PORT) APPROOT=$(APPROOT)
FRONTEND_URL = $(APPROOT)/home
DEV_PORT ?= 3700
DEV_APPROOT = http://localhost:$(DEV_PORT)
DEV_APP_ENV = PORT=$(DEV_PORT) APPROOT=$(DEV_APPROOT)
DEV_FRONTEND_URL = $(DEV_APPROOT)/home

.PHONY: tailwind
tailwind:
	@command -v tailwindcss >/dev/null 2>&1 || (cd $(TAILWIND_DIR) && npm install)
	npx --prefix $(TAILWIND_DIR) tailwindcss -c $(TAILWIND_CONFIG) -i $(TAILWIND_INPUT) -o $(TAILWIND_OUTPUT) --minify

.PHONY: frontend-build
frontend-build:
	@test -d $(FRONTEND_DIR)/node_modules || (cd $(FRONTEND_DIR) && npm install)
	cd $(FRONTEND_DIR) && npm run build
	$(MAKE) tailwind

.PHONY: build-assets
build-assets: frontend-build

.PHONY: rebuild
rebuild:
	@stack clean && stack build

.PHONY: start
start:
	@$(APP_ENV) stack run hkforum

.PHONY: dev-start
dev-start: build-assets
	# @stack exec -- yesod devel
	@/bin/zsh -lc 'exit_code=0; $(DEV_APP_ENV) stack build --flag hkforum:dev && $(DEV_APP_ENV) stack exec hkforum || exit_code=$$?; echo ""; echo "Frontend URL: $(DEV_FRONTEND_URL)"; exit $$exit_code'

.PHONY: start-bg
start-bg:
	@nohup $(APP_ENV) stack run hkforum > ./hkforum.log 2>&1 & echo $$! > ./hkforum.pid

.PHONY: stop
stop:
	@if [ -f ./hkforum.pid ]; then \
		kill $$(cat ./hkforum.pid) || true; \
		rm -f ./hkforum.pid; \
	else \
		echo "No hkforum.pid found."; \
	fi

.PHONY: clean
clean:
	@rm ./data/*.sqlite*

.PHONY: restart
restart:
	$(MAKE) rebuild && $(MAKE) start
