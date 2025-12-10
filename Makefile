.PHONY: help depends validate pull start logs stop compose clean get-version bump-version release changelog docs backup

help:
	@echo "make help         -- show this help"
	@echo "make depends      -- check docker-compose dependencies"
	@echo "make validate	 -- validate docker-compose files"
	@echo "make pull         -- pull or update to latest images"
	@echo "make start        -- start docker-compose services"
	@echo "make logs         -- show docker-compose logs for all services"
	@echo "make stop         -- stop docker-compose services"
	@echo "make compose      -- run docker-compose with arguments"
	@echo "make clean        -- clean leftovers and build files"
	@echo "make get-version  -- get current version"
	@echo "make bump-version -- bump version"
	@echo "make release      -- release new version"
	@echo "make changelog    -- update changelog"
	@echo "make docs         -- generate documentation"
	@echo "make backup       -- backup storage data"

depends:
	./scripts/depends.sh $(MAKEFLAGS)

validate:
	./compose.sh validate

start:
	./compose.sh start -l

pull:
	./compose.sh pull

logs:
	./compose.sh logs

stop:
	./compose.sh stop

compose:
	./compose.sh $(MAKEFLAGS)

clean:
	./scripts/clean.sh $(MAKEFLAGS)

get-version:
	./scripts/get-version.sh

bump-version:
	./scripts/bump-version.sh $(MAKEFLAGS)

release:
	./scripts/release.sh

changelog:
	./scripts/changelog.sh $(MAKEFLAGS)

docs:
	./scripts/docs.sh $(MAKEFLAGS)

backup:
	./scripts/backup.sh
