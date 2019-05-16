FROM amazonlinux:2018.03

RUN yum install -y git make glibc-devel gcc patch openssl-devel lua-devel
RUN git clone --branch v3.3.1 --depth 1 https://github.com/alpinelinux/abuild.git
RUN git clone --branch v2.10.3 --depth 1 https://github.com/alpinelinux/apk-tools.git

WORKDIR /apk-tools
RUN LUA_VERSION=5.1 LUA_PC=lua make

WORKDIR /abuild
RUN make abuild-tar
