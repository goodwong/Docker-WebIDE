FROM debian:11.7-slim

ARG USERNAME=debian
ARG USER_UID=1000
ARG USER_GID=$USER_UID
USER root
# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION=22.11.0
RUN apt-get update \
    #
    # 安装 开发工具
    && apt-get install -y sudo \
    && apt-get install -y openssh-server \
    && apt-get install -y git tree vim tmux curl \
    #
    # 安装依赖的组件
    && apt-get install -y poppler-utils libzbar0 tesseract-ocr \
    && apt-get install -y default-libmysqlclient-dev build-essential \
    # reportlab 的依赖
    && apt-get install -y pkg-config libcairo2-dev \
    #
    # 创建用户
    # Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    #
    # 安装 node 环境
    && mkdir -p $NVM_DIR \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && . $NVM_DIR/nvm.sh && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default \
    && npm install -g pnpm \
    && echo ". $NVM_DIR/nvm.sh" >> /home/$USERNAME/.bashrc \
    #
    # Python 3.12（源码）
    && apt install -y libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libffi-dev zlib1g-dev wget build-essential libreadline-dev \
    && wget https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tar.xz \
    && tar -xvf Python-3.12.0.tar.xz \
    && cd Python-3.12.0/ && ./configure --enable-optimizations && make -j $(nproc) && make altinstall \
    && update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.12 999 \
    && update-alternatives --install /usr/bin/pip3 pip3 /usr/local/bin/pip3.12 999 \
    && cd .. && rm -rf Python-3.12.0.tar.xz /Python-3.12.0/ \
    #
    # Python 3.12（ppa）
    # && apt install software-properties-common -y \
    # && add-apt-repository ppa:deadsnakes/ppa \
    # && apt update && apt install python3.12 \
    # && apt-get install -y python3-pip python3-dev \
    #
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=

# 启动 ssh
EXPOSE 22
ENV SHELL /bin/bash


# code server
RUN curl -#fL -C - https://code-server.dev/install.sh | bash \
    && sudo -u $USERNAME /usr/bin/code-server \
        --install-extension=mhutchie.git-graph \
        --install-extension=mechatroner.rainbow-csv \
        --install-extension=ms-python.python \
        --install-extension=ms-python.pylint \
        --install-extension=ms-python.black-formatter \
        --install-extension=matangover.mypy \
        --install-extension=styled-components.vscode-styled-components


# 安装pip包
COPY requirements.txt ./
RUN http_proxy= https_proxy= pip3 install --no-cache-dir pysocks \
    && pip3 install --no-cache-dir -r requirements.txt
    # 如果代理是socks类型的，pip缺少pysocks库是无法安装任何东西的
    # 所以先忽略proxy，直接安装pysocks
    # 然后就可以愉快的安装其它包啦


USER $USERNAME
ENTRYPOINT []
CMD [ "bash", "/app/.docker/app/docker-entrypoint.sh" ]
