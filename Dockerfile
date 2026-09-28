ARG R_VERSION=4.5
FROM rocker/tidyverse:${R_VERSION}

WORKDIR /home/rstudio/project

# Instala o renv antes de restaurar as dependências do projeto.
RUN R -e "install.packages('renv', repos = 'https://cloud.r-project.org')"

COPY renv.lock ./renv.lock

# Restaura exatamente as versões registradas no renv.lock.
RUN R -e "renv::restore(lockfile = 'renv.lock', prompt = FALSE)"

COPY . .

CMD ["R"]
