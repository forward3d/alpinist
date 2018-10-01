all: build install

build:
	docker build -t apk-tools .
	docker run --name apk-tools apk-tools
	docker cp apk-tools:/apk-tools/src/apk .
	docker cp apk-tools:/abuild/abuild-tar .
	docker rm -f apk-tools

install:
	cp apk abuild-tar ../../lambda/

