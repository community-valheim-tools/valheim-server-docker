FROM debian:trixie-slim AS build-env
ARG TESTS
ARG SOURCE_COMMIT
ARG PYTHON_A2S_VERSION=1.4.1

RUN apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y \
        build-essential \
        curl \
        git \
        golang \
        python3 \
        python3-pip \
        python3-venv \
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
WORKDIR /
RUN rm -rf /usr/local/lib/
# Debian's pip is modded to install to /usr/local by default.
RUN pip3 install --break-system-packages \
        python-a2s==${PYTHON_A2S_VERSION} \
        /build/env2cfg
COPY supervisord.conf /usr/local/etc/supervisord.conf
RUN mkdir -p /usr/local/etc/supervisor/conf.d/ \
    && chmod 640 /usr/local/etc/supervisord.conf
RUN echo "${SOURCE_COMMIT:-unknown}" > /usr/local/etc/git-commit.HEAD


FROM --platform=linux/386 debian:buster-slim AS i386-libs
RUN sed -i -E 's/(deb|security).debian.org/archive.debian.org/g' /etc/apt/sources.list \
    && apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get -y --no-install-recommends install \
    libc6-dev \
    libstdc++6 \
    libsdl2-2.0-0 \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


FROM debian:trixie-slim
COPY --from=build-env /usr/local/ /usr/local/
COPY --from=i386-libs /lib/ld-linux.so.2 /lib/ld-linux.so.2
COPY --from=i386-libs /lib/i386-linux-gnu /lib/i386-linux-gnu
COPY --from=i386-libs /usr/lib/i386-linux-gnu /usr/lib/i386-linux-gnu
COPY fake-supervisord /usr/bin/supervisord

RUN groupadd -g "${PGID:-0}" -o valheim \
    && useradd -g "${PGID:-0}" -u "${PUID:-0}" -o --create-home valheim \
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
    libc6-dev \
    libcurl4 \
    libpulse-dev \
    libsdl2-2.0-0 \
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
    && echo 'LANG="en_US.UTF-8"' > /etc/default/locale \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && rm -f /bin/sh \
    && ln -s /bin/bash /bin/sh \
    && locale-gen \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
    && apt-get clean \
    && mkdir -p /var/spool/cron/crontabs /var/log/supervisor /opt/valheim /opt/steamcmd /home/valheim/.config/unity3d/IronGate /config /var/run/valheim \
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
    && curl -L -o /tmp/steamcmd_linux.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
    && tar xzvf /tmp/steamcmd_linux.tar.gz -C /opt/steamcmd/ \
    && chown -R valheim:valheim /var/run/valheim \
    && chown -R root:root /opt/steamcmd \
    && chmod u=rwx,go=rx /opt/steamcmd/steamcmd.sh \
    && chmod a+s /usr/local/bin/crontab \
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
