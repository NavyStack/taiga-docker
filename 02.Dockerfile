FROM node:18-bookworm as build-stage

ENV PNPM_HOME="/pnpm" \
  PATH="$PNPM_HOME:$PATH" \
  USER=taiga \
  UID=999 \
  GID=999 \
  TZ="Asia/Seoul"

RUN groupadd --gid ${GID} ${USER} \
  && useradd --uid ${UID} --gid ${GID} --home-dir /taiga/ --shell /bin/bash ${USER} \
  && mkdir -p /taiga/ \
  && chown -R ${USER}:${USER} /taiga/

USER ${USER}

RUN git clone --recurse-submodules -j8 --depth 1 https://github.com/taigaio/taiga.git /taiga/

WORKDIR /taiga/javascript/

RUN set -eux; \
    npm install; \
    npm run build:prod;

FROM nginx:latest As Final

LABEL maintainer="navystack@askfront.com"

COPY --from=hairyhenderson/gomplate:stable /gomplate /usr/local/bin/gomplate
COPY --from=build-stage /taiga/javascript/dist/taiga/browser /usr/share/nginx/html
COPY env/config.json.template /
COPY nginx/31-gomplate.sh /docker-entrypoint.d/31-gotemplate.sh