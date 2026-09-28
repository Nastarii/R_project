# Projeto R com Docker

## Desenvolvimento com RStudio

Na primeira execução, construa a imagem e inicie o serviço:

```bash
docker compose build
docker compose up
```

Abra <http://localhost:8787> e use:

- usuário: `rstudio`
- senha: `r-dev`

O diretório do projeto é montado em `/home/rstudio/project` dentro do container.

## Execução de scripts

Para executar o script de exemplo:

```bash
docker compose run --rm rstudio Rscript scripts/main.R
```

Para executar outro script:

```bash
docker compose run --rm rstudio Rscript scripts/meu_script.R
```

## Dependências R com renv

Dentro do RStudio, instale ou atualize os pacotes e depois registre as versões:

```r
install.packages("renv")
renv::init()
renv::snapshot()
```

Depois de alterar o `renv.lock`, reconstrua a imagem:

```bash
docker compose build --no-cache
```

## Parar o ambiente

```bash
docker compose down
```
