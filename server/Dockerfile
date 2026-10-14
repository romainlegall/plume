# syntax=docker/dockerfile:1
#
# plume — image de production pour le Synology.
#
# L'application n'est pas copiee depuis le contexte de build : elle est clonee
# depuis GitHub pendant la construction. Le NAS n'a donc besoin que du dossier
# server/ et de ce Dockerfile, ce qui garde le depot de donnees leger et evite
# de reconstruire l'image a chaque modification locale.

FROM ruby:3.3.4-slim

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    DISABLE_SPRING=1

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libpq-dev \
      postgresql-client \
      curl \
      && rm -rf /var/lib/apt/lists/*

# Node est requis par propshaft pour la compilation des assets.
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

ARG GITHUB_REPO
ARG GITHUB_BRANCH
ARG GITHUB_TOKEN

RUN git clone --depth 1 --branch ${GITHUB_BRANCH:-main} \
      https://${GITHUB_TOKEN}@github.com/${GITHUB_REPO}.git /app

WORKDIR /app

# Les gems sont compiles une fois pour toutes ici : le rebuild ne les refait pas.
RUN bundle install --jobs 4 --retry 3

RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

COPY server/entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["entrypoint.sh"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]