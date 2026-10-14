# syntax=docker/dockerfile:1
# see https://docs.docker.com/reference/dockerfile/

ARG RUBY_VERSION=3.3.4
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# Dependencies rendues disponibles par apt, relances a chaque changement de lockfile.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives


# ---------------------------------------------------------------------------
# Build : les gems sont compiles ici, la couche est ensuite copiee telle quelle
# dans l'image finale. Aucun toolchain de compilation n'y est necessaire.
# ---------------------------------------------------------------------------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

RUN bundle exec bootsnap precompile --no-frozen-cache app/ lib/

# Precompilation des assets et de l'application.
# SECRET_KEY_BASE est factice ici : il n'est utile qu'a la compilation.
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Reinitialise le repertoire pour ne garder que les artefacts de build.
RUN rm -rf log/* tmp/* storage/!(.keep) public/assets/.manifest.json && \
    mkdir -p log tmp storage public/assets


# ---------------------------------------------------------------------------
# Image finale : uniquement le runtime.
# ---------------------------------------------------------------------------
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]