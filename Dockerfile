FROM ubuntu:focal

WORKDIR /app
COPY . /app

# installing all system dependencies, yq, ruby-build and rbenv
RUN apt-get update && \
    apt-get install --yes --no-install-recommends uuid-runtime curl ca-certificates git make build-essential libssl-dev libreadline-dev zlib1g-dev && \
    rm -rf /var/lib/apt/lists/* && \
    curl -L https://github.com/mikefarah/yq/releases/download/v4.24.2/yq_linux_amd64.tar.gz | tar -xzvf - && mv yq_linux_amd64 /usr/bin/yq && \
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv && \
    curl -L https://github.com/sstephenson/ruby-build/archive/v20220324.tar.gz | tar -zxvf - -C /tmp/ && \
    cd /tmp/ruby-build-* && ./install.sh

# set the env
ENV PATH /root/.rbenv/bin:/root/.rbenv/shims:$PATH
RUN echo 'eval "$(rbenv init -)"' >> .bashrc
RUN echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh # or /etc/profile

# run the make file to generate an api key an install the app
RUN make install api_key


EXPOSE 9292
CMD ["make", "run"]
