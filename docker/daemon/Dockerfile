ARG BASE_IMAGE="ubuntu:22.04"
FROM $BASE_IMAGE

USER 0
WORKDIR /root

RUN useradd -u 1000 -G sudo -m -s /bin/bash runner
COPY --chown=runner:runner gitea-actions-runner /home/runner/
COPY --chown=runner:runner worker.sh /home/runner/
COPY --chown=root:root docker-entrypoint.sh /
RUN <<EOS bash
set -ex

apt-get update
apt-get -y --no-install-recommends install ca-certificates curl vim nano sudo wget binutils unzip tar openssh-client tini
apt-get clean
rm -rf /var/lib/apt/lists/*

EOS

RUN <<EOS bash
set -ex

cd /home/runner

chmod +x gitea-actions-runner
chmod +x worker.sh
EOS

USER runner
WORKDIR /home/runner
EXPOSE 1024-65535

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
