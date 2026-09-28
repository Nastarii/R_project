ARG R_VERSION=4.5.0
ARG RLAB_UID=1000
ARG RLAB_GID=1000
FROM rocker/r-ver:${R_VERSION}

ARG RLAB_UID
ARG RLAB_GID

ENV DEBIAN_FRONTEND=noninteractive \
    R_LIBS_USER=/home/ruser/R/library \
    R_LAB_WORKSPACE=/workspace \
    R_LAB_PORT=3838

# A base R oficial, sem RStudio e sem o tidyverse completo.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl libcurl4-openssl-dev libssl-dev libxml2-dev \
       libfontconfig1-dev libfreetype6-dev libpng-dev libjpeg-dev \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid ${RLAB_GID} ruser \
    && useradd --uid ${RLAB_UID} --gid ${RLAB_GID} --create-home --shell /bin/bash ruser \
    && mkdir -p /home/ruser/R/library /workspace \
    && chown -R ruser:ruser /home/ruser /workspace

# Dependências permanentes da interface; pacotes dos projetos são instalados
# depois, pelo usuário, na biblioteca persistente montada pelo Compose.
RUN install2.r --error --skipinstalled shiny bslib DT processx \
    && rm -rf /tmp/downloaded_packages /tmp/Rtmp*

COPY app /workspace/app
RUN chown -R ruser:ruser /workspace/app

USER ruser
WORKDIR /workspace
EXPOSE 3838

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${R_LAB_PORT}/" >/dev/null || exit 1

CMD ["R", "--vanilla", "-q", "-e", "shiny::runApp('/workspace/app/app.R', host = '0.0.0.0', port = as.integer(Sys.getenv('R_LAB_PORT', '3838')))" ]
