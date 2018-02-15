FROM amazonlinux:latest

RUN yum clean all -y
RUN yum install -y git make glibc-devel gcc patch openssl-devel lua-devel
RUN git clone https://github.com/alpinelinux/abuild.git
RUN git clone https://github.com/alpinelinux/apk-tools.git

WORKDIR /apk-tools
RUN make

WORKDIR /abuild
RUN make abuild-tar
