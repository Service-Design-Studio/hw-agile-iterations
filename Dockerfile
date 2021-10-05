# Use the official lightweight Ruby image.
# https://hub.docker.com/_/ruby
FROM ruby:2.6.5 AS rails-toolbox

SHELL ["/bin/bash", "-c"]

RUN (curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.0/install.sh | bash)


# Install production dependencies.
WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN apt-get update && apt-get install -y libpq-dev && apt-get install -y python3-distutils-extra

RUN gem install bundler:1.17.3 && \
    bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle config set path vendor/bundle && \
    #bundle config set without production && \
    bundle install

# Copy local code to the container image.
COPY . /app

ENV RAILS_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true
# Redirect Rails log to STDOUT for Cloud Run to capture
ENV RAILS_LOG_TO_STDOUT=true

# pre-compile Rails assets with master key
ARG RAILS_MASTER_KEY
RUN (source ~/.bashrc && nvm install 12.13.1 && npm install -g yarn@1.22.4 && RAILS_MASTER_KEY=${RAILS_MASTER_KEY} SECRET_KEY_BASE=1 bundle exec rake assets:precompile)

EXPOSE 8080

CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "8080"]

