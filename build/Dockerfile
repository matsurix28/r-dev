FROM r-base:latest

ARG UID=1000
ARG GID=1000
ARG PSWD=pswd

ENV USERID ${UID}
ENV GROUPID ${GID}
ENV PASSWORD ${PSWD}

RUN apt update \
    && apt install -y sudo \
    libcurl4-openssl-dev \
    libxml2-dev \
    libxt-dev \
    git \
    openssh-client \
    libssl-dev \
    && GROUP=`grep -E "^[^:]+:[^:]+:${GID}:" /etc/group` || true \
    && if [ -z "${GROUP}" ]; then groupadd -g ${GID} container-group; fi \
    && usermod -u ${UID} -g ${GID} docker \
    && gpasswd -a docker sudo \
    && echo "docker ALL=(ALL) ALL" >> /etc/sudoers \
    && echo "docker:${PSWD}" | chpasswd 

USER docker

RUN mkdir -p /home/docker/.cache/R/renv /home/docker/library

WORKDIR /home/docker/workspace

CMD echo ${PASSWORD} | sudo -S chown -R ${USERID}:${GROUPID} /home/docker/workspace \
    && umask 0002 \
    && bash /home/docker/workspace/build/container.sh
