FROM ubuntu:22.04 as base
WORKDIR /workdir

ARG sdk_nrf_branch=v2.4-branch
ARG toolchain_version=v2.4.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get -y install wget unzip

# Install toolchain
# Make nrfutil install in a shared location, because when used with GitHub
# Actions, the image will be launched with the home dir mounted from the local
# checkout.
ENV NRFUTIL_HOME=/usr/local/share/nrfutil
RUN wget -q https://developer.nordicsemi.com/.pc-tools/nrfutil/x64-linux/nrfutil
RUN mv nrfutil /usr/local/bin
RUN chmod +x /usr/local/bin/nrfutil
RUN nrfutil install toolchain-manager
RUN nrfutil install toolchain-manager search
RUN nrfutil toolchain-manager install --ncs-version ${toolchain_version}
RUN nrfutil toolchain-manager list

#
# ClangFormat
#
RUN apt-get -y install clang-format
RUN wget -qO- https://raw.githubusercontent.com/nrfconnect/sdk-nrf/${sdk_nrf_branch}/.clang-format > /workdir/.clang-format

# Nordic command line tools
# Releases: https://www.nordicsemi.com/Products/Development-tools/nrf-command-line-tools/download
RUN mkdir tmp && cd tmp
RUN wget -q https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/desktop-software/nrf-command-line-tools/sw/versions-10-x-x/10-23-2/nrf-command-line-tools-10.23.2_linux-amd64.tar.gz
RUN tar xzf nrf-command-line-tools-10.23.2_linux-amd64.tar.gz

# Install included JLink
RUN mkdir /opt/SEGGER
RUN tar xzf JLink_*.tgz -C /opt/SEGGER
RUN mv /opt/SEGGER/JLink* /opt/SEGGER/JLink

# Install nrf-command-line-tools
RUN cp -r ./nrf-command-line-tools /opt
RUN ln -s /opt/nrf-command-line-tools/bin/nrfjprog /usr/local/bin/nrfjprog
RUN ln -s /opt/nrf-command-line-tools/bin/mergehex /usr/local/bin/mergehex
RUN cd .. && rm -rf tmp ;

# Prepare image with a ready to use build environment
SHELL ["nrfutil","toolchain-manager","launch","/bin/bash","--","-c"]
RUN west init -m https://github.com/nrfconnect/sdk-nrf --mr ${sdk_nrf_branch} .
RUN west update --narrow -o=--depth=1

# Launch into build environment with the passed arguments
# Currently this is not supported in GitHub Actions
# See https://github.com/actions/runner/issues/1964
ENTRYPOINT [ "nrfutil", "toolchain-manager", "launch", "/bin/bash", "--", "/root/entry.sh" ]
COPY ./entry.sh /root/entry.sh