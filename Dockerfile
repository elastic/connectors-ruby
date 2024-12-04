FROM ubuntu:noble-20241118.1

WORKDIR /app
COPY . /app

# installing all system dependencies, yq, ruby-build and rbenv
RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
    uuid-runtime curl ca-certificates git make build-essential \
    libssl-dev libreadline-dev zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*
RUN curl -L https://github.com/mikefarah/yq/releases/download/v4.40.2/yq_linux_amd64.tar.gz | tar -xzvf - && \
    mv yq_linux_amd64 /usr/bin/yq
RUN git clone https://github.com/rbenv/rbenv.git ~/.rbenv && \
    curl -L https://github.com/sstephenson/ruby-build/archive/v20231114.tar.gz | tar -zxvf - -C /tmp/ && \
    cd /tmp/ruby-build-* && \
    ./install.sh

# set the env
ENV PATH /root/.rbenv/bin:/root/.rbenv/shims:$PATH
RUN echo 'eval "$(rbenv init -)"' >> .bashrc
RUN echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh

# run the make file to install the app
# override CFLAGS because -w (warning suppression) screws up ruby-build in newer versions
# when compiling ruby 2.6.x, *but* we need newer ruby-build to compile older openssl
# on newer Ubuntu releases
RUN make install RUBY_CFLAGS=''

CMD ["/bin/bash", "script/run_in_docker.sh"]
