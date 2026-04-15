FROM alpine:3 AS builder

ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1
ENV BOOTSTRAP_HASKELL_MINIMAL=1
ENV BOOTSTRAP_HASKELL_GHC_VERSION=9.10.3
ENV BOOTSTRAP_HASKELL_INSTALL_STACK=1
ENV BOOTSTRAP_HASKELL_INSTALL_HLS=0
ENV PATH="/root/.ghcup/bin:/root/.local/bin:${PATH}"

RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    gcc \
    g++ \
    git \
    gmp-dev \
    libc-dev \
    libffi-dev \
    make \
    musl-dev \
    ncurses-dev \
    openssl-dev \
    perl \
    pkgconf \
    sqlite-dev \
    tar \
    xz \
    zlib-dev

RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

WORKDIR /app

COPY stack.yaml stack.yaml.lock package.yaml hkforum.cabal ./
COPY app ./app
COPY config ./config
COPY src ./src
COPY static ./static
COPY templates ./templates

RUN stack build --system-ghc --no-install-ghc --copy-bins --local-bin-path /out

FROM alpine:3 AS runtime

RUN apk add --no-cache \
    ca-certificates \
    gmp \
    libstdc++ \
    sqlite-libs \
    tzdata \
    zlib \
 && adduser -D -h /app appuser \
 && mkdir -p /app/data/uploads \
 && chown -R appuser:appuser /app

WORKDIR /app

COPY --from=builder /out/hkforum /usr/local/bin/hkforum
COPY --chown=appuser:appuser config ./config
COPY --chown=appuser:appuser static ./static

ENV PORT=3000
ENV STORAGE_BACKEND=local

EXPOSE 3000

USER appuser

CMD ["hkforum"]
