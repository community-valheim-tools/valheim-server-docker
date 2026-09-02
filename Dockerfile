ARG PYTHON_A2S_VERSION=1.4.2

FROM steamcmd/steamcmd:debian-trixie AS build-env
ARG TESTS
ARG SOURCE_COMMIT
ARG PYTHON_A2S_VERSION
RUN apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y \
        build-essential \
        golang \
        python3 \
        python3-pip \
        shellcheck \
        tox

WORKDIR /build/env2cfg
COPY ./env2cfg/ /build/env2cfg/
RUN if [ "${TESTS:-true}" = true ]; then \
        tox \
    ; \
    fi

WORKDIR /build/valheim-logfilter
COPY ./valheim-logfilter/ /build/valheim-logfilter/
RUN if [ "${TESTS:-true}" = true ]; then \
        go test ./... \
    ; \
    fi
RUN go build -ldflags="-s -w" \
    && mv valheim-logfilter /usr/local/bin/

WORKDIR /build
COPY ./usr/local/ /usr/local/
RUN if [ "${TESTS:-true}" = true ]; then \
        shellcheck -a -x -s bash -e SC2034 \
        /usr/local/sbin/bootstrap \
        /usr/local/bin/valheim-tests \
        /usr/local/bin/valheim-backup \
        /usr/local/bin/valheim-is-idle \
        /usr/local/bin/valheim-bootstrap \
        /usr/local/bin/valheim-server \
        /usr/local/bin/valheim-updater \
        /usr/local/bin/valheim-plus-updater \
        /usr/local/bin/bepinex-updater \
        /usr/local/share/valheim/contrib/*.sh \
        ; \
    fi


FROM steamcmd/steamcmd:debian-trixie
ARG PYTHON_A2S_VERSION
COPY ./usr/local/ /usr/local/
COPY --from=build-env /usr/local/bin/valheim-logfilter /usr/local/bin/valheim-logfilter
RUN groupadd -g "${PGID:-0}" -o valheim \
    && useradd -g "${PGID:-0}" -u "${PUID:-0}" -o --create-home valheim \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
    busybox \
    ca-certificates \
    curl \
    daemontools \
    iproute2 \
    jq \
    libatomic1 \
    libc6 \
    libc6:i386 \
    libc6-dev \
    libc6-dev:i386 \
    libcurl4 \
    libcurl4:i386 \
    libpulse-dev \
    libsdl2-2.0-0 \
    libsdl2-2.0-0:i386 \
    libstdc++6 \
    libstdc++6:i386 \
    locales \
    lsof \
    openssh-client \
    procps \
    python3 \
    python3-pip \
    python3-pkg-resources \
    python3-setuptools \
    rsync \
    supervisor \
    sysstat \
    tini \
    unzip \
    zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && pip3 install --break-system-packages python-a2s==${PYTHON_A2S_VERSION} \
    && echo 'LANG="en_US.UTF-8"' > /etc/default/locale \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
    && mkdir -p /config /home/valheim/.config/unity3d/IronGate /opt/valheim /usr/local/etc/supervisor/conf.d/ /var/log/supervisor /var/spool/cron/crontabs /var/run/valheim \
    && ln -s /config /home/valheim/.config/unity3d/IronGate/Valheim \
    && ln -s /usr/bin/busybox /usr/local/bin/bc \
    && ln -s /usr/bin/busybox /usr/local/bin/bunzip2 \
    && ln -s /usr/bin/busybox /usr/local/bin/bzcat \
    && ln -s /usr/bin/busybox /usr/local/bin/bzip2 \
    && ln -s /usr/bin/busybox /usr/local/bin/crontab \
    && ln -s /usr/bin/busybox /usr/local/bin/httpd \
    && ln -s /usr/bin/busybox /usr/local/bin/killall \
    && ln -s /usr/bin/busybox /usr/local/bin/less \
    && ln -s /usr/bin/busybox /usr/local/bin/ping \
    && ln -s /usr/bin/busybox /usr/local/bin/ping6 \
    && ln -s /usr/bin/busybox /usr/local/bin/ssl_client \
    && ln -s /usr/bin/busybox /usr/local/bin/traceroute \
    && ln -s /usr/bin/busybox /usr/local/bin/traceroute6 \
    && ln -s /usr/bin/busybox /usr/local/bin/unxz \
    && ln -s /usr/bin/busybox /usr/local/bin/vi \
    && ln -s /usr/bin/busybox /usr/local/bin/wget \
    && ln -s /usr/bin/busybox /usr/local/bin/xz \
    && ln -s /usr/bin/busybox /usr/local/bin/xzcat \
    && ln -s /usr/bin/busybox /usr/local/bin/xxd \
    && ln -s /usr/bin/busybox /usr/local/sbin/crond \
    && ln -s /usr/bin/busybox /usr/local/sbin/mkpasswd \
    && ln -s /usr/bin/busybox /usr/local/sbin/syslogd \
    && chown -R valheim:valheim /var/run/valheim \
    && chmod a+s /usr/local/bin/crontab \
    /usr/bin/supervisord \
    && su - valheim -c "/usr/bin/steamcmd +login anonymous +quit" \
    && date --utc --iso-8601=seconds > /usr/local/etc/build.date \
    && echo "${SOURCE_COMMIT:-unknown}" > /usr/local/etc/git-commit.HEAD


EXPOSE 2456-2458/udp
EXPOSE 9001/tcp
EXPOSE 80/tcp
WORKDIR /
CMD ["/usr/local/sbin/bootstrap"]
ENTRYPOINT []
