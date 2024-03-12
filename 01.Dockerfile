FROM python:3.11-bookworm AS git
RUN git clone --recurse-submodules -j8 --depth 1 https://github.com/taigaio/taiga.git /taiga-base/

FROM python:3.11-bookworm AS env-builder

ARG TARGETARCH

WORKDIR /taiga

COPY --from=git /taiga-base/python/apps/taiga/requirements/prod.txt /taiga/requirements.txt

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get -y --no-install-recommends install \
        locales \
        tini \
        build-essential \
        libpq5 \
        libpq-dev \
        wget

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
RUN dpkg-reconfigure --frontend=noninteractive locales

RUN python3 -m venv /venv

RUN /venv/bin/python3 -m pip install --upgrade pip wheel setuptools
RUN /venv/bin/python3 -m pip install -r requirements.txt -v

COPY --from=git /taiga-base/python/apps/taiga/ /taiga/

RUN set -eux; \
    /venv/bin/python3 -m pip install -e .; \
    /venv/bin/python3 -m taiga i18n compile-catalog; \
    /venv/bin/python3 -m taiga collectstatic;

RUN find . -type f \( -name '__pycache__' -o -name '*.pyc' -o -name '*.pyo' \) -exec bash -c 'echo "Deleting {}"; rm -f {}' \;
RUN rm -rf /taiga/requirements.txt
RUN rm -rf /taiga/apps/taiga/requirements/

FROM python:3.11-slim-bookworm AS final
LABEL maintainer="navystack@askfront.com"

WORKDIR /taiga

ARG USER=taiga
RUN groupadd --system --gid 999 ${USER} && \
    useradd --system --gid ${USER} --no-create-home --home /nonexistent --comment "taiga user" --shell=/bin/bash --uid 999 ${USER} \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        libpq5 \
        libpq-dev \
        wget \
        tini \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=env-builder --chown=${USER}:${USER} /taiga/ /taiga/
COPY --from=env-builder --chown=${USER}:${USER} /venv /venv

USER ${USER}
ENTRYPOINT ["tini", "--", "/venv/bin/python3", "-m", "taiga"]

CMD ["--help"]