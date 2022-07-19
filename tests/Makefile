.PHONY: run-stack

export VERSION=8.4.0-SNAPSHOT

run-stack:
	docker-compose up -d

stop-stack:
	docker-compose down --volumes

load-data:
	../loadsample.sh
