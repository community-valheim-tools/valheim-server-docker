FROM debian:trixie-slim AS build-env
ENV DEBIAN_FRONTEND=noninteractive
ARG TESTS
ARG SOURCE_COMMIT
ARG BUSYBOX_VERSION=1.36.1
ARG SUPERVISOR_VERSION=4.2.5
ARG GO_VERSION=1.24.1

RUN apt-get update
RUN apt-get -y install apt-utils
RUN apt-get -y install build-essential curl git python3 python3-setuptools python3-pip pipx shellcheck

# Install Go 1.24 manually
RUN curl -L -o /tmp/go${GO_VERSION}.linux-amd64.tar.gz https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf /tmp/go${GO_VERSION}.linux-amd64.tar.gz \
    && rm /tmp/go${GO_VERSION}.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin
ENV GOPATH=/go
ENV PATH=$PATH:$GOPATH/bin

WORKDIR /build/busybox
RUN curl -L -o /tmp/busybox.tar.bz2 https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2 \
    && tar xjvf /tmp/busybox.tar.bz2 --strip-components=1 -C /build/busybox \
    && make defconfig \
    && sed -i -e "s/^CONFIG_FEATURE_SYSLOGD_READ_BUFFER_SIZE=.*/CONFIG_FEATURE_SYSLOGD_READ_BUFFER_SIZE=2048/" .config \
    && sed -i -e "s/^CONFIG_TC=y/CONFIG_TC=n/" .config \
    && make \
    && cp busybox /usr/local/bin/

WORKDIR /build/env2cfg
COPY ./env2cfg/ /build/env2cfg/
RUN if [ "${TESTS:-true}" = true ]; then \
    pipx ensurepath && pipx install tox \
    && /root/.local/bin/tox \
    ; \
    fi
RUN python3 setup.py bdist --format=gztar

WORKDIR /build/valheim-logfilter
COPY ./valheim-logfilter/ /build/valheim-logfilter/
RUN if [ "${TESTS:-true}" = true ]; then \
    go test ./... \
    ; \
    fi
RUN go build -ldflags="-s -w" \
    && mv valheim-logfilter /usr/local/bin/

WORKDIR /build
RUN git clone https://github.com/Yepoleb/python-a2s.git \
    && cd python-a2s \
    && python3 setup.py bdist --format=gztar

WORKDIR /build/supervisor
RUN curl -L -o /tmp/supervisor.tar.gz https://github.com/Supervisor/supervisor/archive/${SUPERVISOR_VERSION}.tar.gz \
    && tar xzvf /tmp/supervisor.tar.gz --strip-components=1 -C /build/supervisor \
    && python3 setup.py bdist --format=gztar

COPY bootstrap /usr/local/sbin/
COPY valheim-tests /usr/local/bin/
COPY valheim-status /usr/local/bin/
COPY valheim-is-idle /usr/local/bin/
COPY valheim-bootstrap /usr/local/bin/
COPY valheim-backup /usr/local/bin/
COPY valheim-updater /usr/local/bin/
COPY valheim-plus-updater /usr/local/bin/
COPY bepinex-updater /usr/local/bin/
COPY valheim-server /usr/local/bin/
COPY defaults /usr/local/etc/valheim/
COPY common /usr/local/etc/valheim/
COPY contrib/* /usr/local/share/valheim/contrib/
RUN chmod 755 /usr/local/sbin/bootstrap /usr/local/bin/valheim-*
RUN if [ "${TESTS:-true}" = true ]; then \
    shellcheck -a -x -s bash -e SC2034 --severity=error \
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
WORKDIR /
RUN rm -rf /usr/local/lib/
RUN tar xzvf /build/supervisor/dist/supervisor-*.linux-x86_64.tar.gz
RUN tar xzvf /build/env2cfg/dist/env2cfg-*.linux-x86_64.tar.gz
RUN tar xzvf /build/python-a2s/dist/python_a2s-*.linux-x86_64.tar.gz
COPY supervisord.conf /usr/local/etc/supervisord.conf
RUN mkdir -p /usr/local/etc/supervisor/conf.d/ \
    && chmod 640 /usr/local/etc/supervisord.conf
RUN echo "${SOURCE_COMMIT:-unknown}" > /usr/local/etc/git-commit.HEAD


FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive
COPY --from=build-env /usr/local/ /usr/local/
COPY fake-supervisord /usr/bin/supervisord

RUN groupadd -g "${PGID:-0}" -o valheim \
    && useradd -g "${PGID:-0}" -u "${PUID:-0}" -o --create-home valheim \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get -y --no-install-recommends install apt-utils \
    && apt-get -y dist-upgrade \
    && apt-get -y --no-install-recommends install \
    libc6-dev:i386 \
    libstdc++6:i386 \
    libsdl2-2.0-0:i386 \
    libcurl4:i386 \
    libc6-dev \
    libsdl2-2.0-0 \
    cron \
    curl \
    iproute2 \
    libcurl4 \
    ca-certificates \
    procps \
    locales \
    unzip \
    zip \
    rsync \
    openssh-client \
    jq \
    python3-minimal \
    python3-pkg-resources \
    python3-setuptools \
    libpulse-dev \
    libatomic1 \
    libc6 \
    tini \
    && echo 'LANG="en_US.UTF-8"' > /etc/default/locale \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && rm -f /bin/sh \
    && ln -s /bin/bash /bin/sh \
    && locale-gen \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
    && usermod -a -G crontab valheim \
    && apt-get clean \
    && mkdir -p /var/spool/cron/crontabs /var/log/supervisor /opt/valheim /opt/steamcmd /home/valheim/.config/unity3d/IronGate /config /var/run/valheim \
    && ln -s /config /home/valheim/.config/unity3d/IronGate/Valheim \
    && ln -s /usr/local/bin/busybox /usr/local/sbin/syslogd \
    && ln -s /usr/local/bin/busybox /usr/local/sbin/mkpasswd \
    && ln -s /usr/local/bin/busybox /usr/local/bin/vi \
    && ln -s /usr/local/bin/busybox /usr/local/bin/patch \
    && ln -s /usr/local/bin/busybox /usr/local/bin/unix2dos \
    && ln -s /usr/local/bin/busybox /usr/local/bin/dos2unix \
    && ln -s /usr/local/bin/busybox /usr/local/bin/makemime \
    && ln -s /usr/local/bin/busybox /usr/local/bin/xxd \
    && ln -s /usr/local/bin/busybox /usr/local/bin/wget \
    && ln -s /usr/local/bin/busybox /usr/local/bin/less \
    && ln -s /usr/local/bin/busybox /usr/local/bin/lsof \
    && ln -s /usr/local/bin/busybox /usr/local/bin/httpd \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ssl_client \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ip \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ipcalc \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ping \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ping6 \
    && ln -s /usr/local/bin/busybox /usr/local/bin/iostat \
    && ln -s /usr/local/bin/busybox /usr/local/bin/setuidgid \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ftpget \
    && ln -s /usr/local/bin/busybox /usr/local/bin/ftpput \
    && ln -s /usr/local/bin/busybox /usr/local/bin/bzip2 \
    && ln -s /usr/local/bin/busybox /usr/local/bin/xz \
    && ln -s /usr/local/bin/busybox /usr/local/bin/pstree \
    && ln -s /usr/local/bin/busybox /usr/local/bin/killall \
    && ln -s /usr/local/bin/busybox /usr/local/bin/bc \
    && curl -L -o /tmp/steamcmd_linux.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    && tar xzvf /tmp/steamcmd_linux.tar.gz -C /opt/steamcmd/ \
    && chown valheim:valheim /var/run/valheim \
    && chown -R root:root /opt/steamcmd \
    && chmod 755 /opt/steamcmd/steamcmd.sh \
    /opt/steamcmd/linux32/steamcmd \
    /opt/steamcmd/linux32/steamerrorreporter \
    /usr/bin/supervisord \
    && cd "/opt/steamcmd" \
    && su - valheim -c "/opt/steamcmd/steamcmd.sh +login anonymous +quit" \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && date --utc --iso-8601=seconds > /usr/local/etc/build.date

EXPOSE 2456-2458/udp
EXPOSE 9001/tcp
EXPOSE 80/tcp
WORKDIR /
CMD ["/usr/local/sbin/bootstrap"]
