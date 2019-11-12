FROM golang:1.13.4-alpine3.10

ARG SQLITE_VER=version-3.30.1+replication3
ARG LIBCO_VER=v19.1
ARG RAFT_VER=v0.9.9
ARG DQLITE_VER=v1.1.0
ARG DQLITE_DEMO_VER=v1.1.0

ENV PREFIX /usr/local
ENV CONFIG_FLAGS --prefix=$PREFIX
ENV PKG_CONFIG_PATH $PREFIX/lib/pkgconfig/

WORKDIR /build

RUN apk -U -q --no-cache add \
    coreutils git gcc make autoconf automake build-base gperf bison flex texinfo libtool tcl help2man \
    curl wget tar sed gawk zip unzip xz bash vim less file python3 py3-pip \
    musl-dev gettext-dev ncurses-dev openssl-dev libffi-dev libseccomp-dev libuv-dev libuv-static abuild

RUN rm -rf /usr/local/lib /usr/local/include

COPY patch /patch/

# --- Build patched sqlite

RUN apk add sudo
RUN adduser -h /home/build -G abuild -D -s /bin/bash build
COPY sqlite sqlite
RUN cd sqlite && \
    chown -R build . && \
    sudo -u build -- abuild-keygen -a -n && \
    sudo -u build -- abuild -r
RUN apk add --allow-untrusted /home/build/packages/build/*/*.apk
RUN mkdir -p $PREFIX/packages && \
    cp /home/build/packages/build/*/*.apk $PREFIX/packages

# --- Build libco

RUN git clone -b $LIBCO_VER https://github.com/canonical/libco.git && \
    cd libco && \
    ls /patch/libco-* | xargs -r -n1 patch -p1 -i && \
    make && \
    make install

# --- Build raft

RUN git clone -b $RAFT_VER https://github.com/canonical/raft.git && \
    cd raft && \
    ls /patch/raft-* | xargs -r -n1 patch -p1 -i && \
    autoreconf -i && \
    ./configure $CONFIG_FLAGS && \
    make && \
    make install

# --- Build dqlite

RUN git clone -b $DQLITE_VER https://github.com/canonical/dqlite.git && \
    cd dqlite && \
    ls /patch/dqlite-* | xargs -r -n1 patch -p1 -i && \
    autoreconf -i && \
    ./configure $CONFIG_FLAGS && \
    make && \
    make install

# --- Build static dqlite-demo

RUN go get -d github.com/spf13/cobra
RUN go get -d github.com/canonical/go-dqlite && \
    cd /go/src/github.com/canonical/go-dqlite && \
    git checkout $DQLITE_DEMO_VER && \
    ls /patch/go-dqlite-* | xargs -r -n1 patch -p1 -i && \
    go install \
        -tags libsqlite3 \
        -ldflags "-w -s -extldflags '-static'" \
        ./cmd/dqlite-demo

# --- Create artifact

ENV DIST /dist/artifacts

ARG DRONE_STAGE_ARCH
ENV ARCH $DRONE_STAGE_ARCH

RUN mkdir -p $DIST && \
    tar czf $DIST/dqlite-$ARCH.tgz $PREFIX/lib $PREFIX/include $PREFIX/packages

# --- Perform release

RUN GO111MODULE=on go get github.com/drone-plugins/drone-github-release@v1.0.0

ARG GITHUB_TOKEN
ENV GITHUB_TOKEN $GITHUB_TOKEN

ARG DRONE_BUILD_EVENT
ENV DRONE_BUILD_EVENT $DRONE_BUILD_EVENT

ARG DRONE_REPO_OWNER
ENV DRONE_REPO_OWNER $DRONE_REPO_OWNER

ARG DRONE_REPO_NAME
ENV DRONE_REPO_NAME $DRONE_REPO_NAME

ARG DRONE_COMMIT_REF
ENV DRONE_COMMIT_REF $DRONE_COMMIT_REF

RUN if [ "$DRONE_BUILD_EVENT" = "tag" ]; then \
        drone-github-release --files="$DIST/*"; \
    fi
