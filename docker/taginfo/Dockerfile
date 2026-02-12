FROM ruby:4.0-slim

WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    libicu-dev \
    libsqlite3-dev \
    sqlite3 \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/taginfo/taginfo.git /usr/src/app/taginfo

WORKDIR /usr/src/app/taginfo

RUN sed -i "s/#set :bind, '0.0.0.0'/set :bind, '0.0.0.0'/" /usr/src/app/taginfo/web/taginfo.rb

RUN printf "\\n# Added for rack handler\\ngem 'webrick'\\n" >> Gemfile

RUN gem install --no-document bundler webrick && \
    bundle config set --local without 'development test' && \
    bundle install

COPY taginfo-config.json /usr/src/app/taginfo-config.json
COPY start.sh /usr/src/app/start.sh

EXPOSE 4567

CMD ["/usr/src/app/start.sh"]
