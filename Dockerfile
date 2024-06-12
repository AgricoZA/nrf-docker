FROM ubuntu:22.04 as base
WORKDIR /workdir

ARG sdk_nrf_branch=v2.4-branch
ARG toolchain_version=v2.4.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update \
 && apt-get -y upgrade \
 && apt-get -y install wget unzip gcc gcc-multilib clang-format libffi7

# Install toolchain
# Make nrfutil install in a shared location, because when used with GitHub
# Actions, the image will be launched with the home dir mounted from the local
# checkout.
ENV NRFUTIL_HOME=/usr/local/share/nrfutil
RUN wget -q https://developer.nordicsemi.com/.pc-tools/nrfutil/x64-linux/nrfutil \
 && mv nrfutil /usr/local/bin \
 && chmod +x /usr/local/bin/nrfutil
RUN nrfutil install toolchain-manager \
 && nrfutil install toolchain-manager search \
 && nrfutil toolchain-manager install --ncs-version ${toolchain_version} \
 && nrfutil toolchain-manager list

# Nordic command line tools
# Releases: https://www.nordicsemi.com/Products/Development-tools/nrf-command-line-tools/download
#
# Install included JLink
#
# Install nrf-command-line-tools
#
# Install libffi7
RUN wget -qO- https://raw.githubusercontent.com/nrfconnect/sdk-nrf/${sdk_nrf_branch}/.clang-format > /workdir/.clang-format \
 && mkdir tmp \ 
 && cd tmp \
 && wget -q https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/desktop-software/nrf-command-line-tools/sw/versions-10-x-x/10-23-2/nrf-command-line-tools-10.23.2_linux-amd64.tar.gz \
 && tar xzf nrf-command-line-tools-10.23.2_linux-amd64.tar.gz \
 && mkdir /opt/SEGGER \
 && tar xzf JLink_*.tgz -C /opt/SEGGER \
 && mv /opt/SEGGER/JLink* /opt/SEGGER/JLink \
 && cp -r ./nrf-command-line-tools /opt \
 && ln -s /opt/nrf-command-line-tools/bin/nrfjprog /usr/local/bin/nrfjprog \
 && ln -s /opt/nrf-command-line-tools/bin/mergehex /usr/local/bin/mergehex 

# Prepare image with a ready to use build environment
SHELL ["nrfutil","toolchain-manager","launch","/bin/bash","--","-c"]
RUN west init -m https://github.com/nrfconnect/sdk-nrf --mr ${sdk_nrf_branch} . \
 && west update --narrow -o=--depth=1

ADD ./zephyr_support_files /workdir/zephyr/drivers/ethernet

# Launch into build environment with the passed arguments
# Currently this is not supported in GitHub Actions
# See https://github.com/actions/runner/issues/1964
ENTRYPOINT [ "nrfutil", "toolchain-manager", "launch", "/bin/bash", "--", "/root/entry.sh" ]
COPY ./entry.sh /root/entry.sh