# R Lab

Ambiente local e leve para executar projetos R usando Docker e Shiny, sem
RStudio. A imagem usa `rocker/r-ver`, instala somente as dependências da
interface e executa o código dos projetos a partir de `/workspace`.

## Iniciar

```bash
docker compose up -d --build
```

Acesse <http://localhost:3838>. O serviço é publicado somente em localhost
por padrão. Para acompanhar a inicialização:

```bash
docker compose logs -f r-lab
```

O diretório inteiro do projeto local é montado em `/workspace`. Alterações em
scripts, dados ou no app ficam disponíveis imediatamente e não exigem rebuild.
Reconstrua apenas quando alterar o `Dockerfile` ou as dependências fixas da
imagem.

## Interface

Há duas áreas principais:

- **Ambiente** mostra versões do R e Shiny, diretório do projeto e quantidade
  de pacotes. Permite pesquisar no CRAN, instalar, atualizar e remover pacotes.
  Essas operações rodam em processos separados e usam uma biblioteca
  persistente (`r-lab-library`).
- **Executar scripts** lista arquivos `.R`, executa um por vez, permite
  interromper, mostra stdout/stderr em tempo real, duração e código de saída.
  Resultados em `output/` e `assets/` podem ser listados, visualizados e
  baixados. CSV e TSV são exibidos como tabelas; PNG e JPEG como imagens.

O seletor de tema claro/escuro fica na área **Ambiente**.

## Estrutura

```text
app/
├── app.R
├── modules/
│   ├── environment.R
│   └── execution.R
├── services/
│   ├── package_manager.R
│   ├── package_worker.R
│   ├── result_viewer.R
│   └── script_runner.R
└── www/style.css
data/       # entradas do projeto
scripts/    # scripts R executáveis
output/     # tabelas e arquivos gerados
assets/     # imagens e outros artefatos
logs/       # logs persistidos das execuções
```

Scripts devem usar caminhos relativos ao diretório do projeto e gravar seus
resultados em `output/` ou `assets/`. A execução ocorre com
`Rscript --vanilla`, em processo independente, com diretório de trabalho
`/workspace`.

## Configuração

As variáveis abaixo podem ser colocadas em um arquivo `.env` ou informadas na
linha de comando:

| Variável | Padrão | Uso |
|---|---:|---|
| `R_LAB_PORT` | `3838` | Porta do Shiny no host e no container |
| `R_LAB_HOST` | `127.0.0.1` | Endereço de bind do host |
| `R_LAB_CPUS` | `2.0` | Limite de CPU |
| `R_LAB_MEMORY` | `2g` | Limite de memória |
| `R_LAB_TIMEOUT_SECONDS` | `3600` | Tempo máximo de scripts e operações |
| `R_VERSION` | `4.5.0` | Versão da imagem base do R |

Exemplo:

```bash
R_LAB_PORT=8080 R_LAB_MEMORY=4g docker compose up -d
```

## Pacotes e renv

O MVP não exige `renv`: pacotes instalados pela interface vão para a
biblioteca persistente e continuam disponíveis após reiniciar o container.
O `renv.lock` existente pode ser usado pelo próprio projeto, se desejado,
mas não é restaurado durante o build da imagem; isso mantém o build rápido e
independente dos scripts locais.

Para execução direta, sem abrir a interface:

```bash
docker compose run --rm r-lab Rscript --vanilla scripts/main.R
```

## Parar e atualizar

```bash
docker compose down
docker compose up -d --build
```

Biblioteca, logs e resultados permanecem no volume ou no diretório local.
Scripts R executam código arbitrário: use somente projetos confiáveis e não
publique a porta fora de uma rede controlada.
