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


## Pasta local montada

O navegador nao pode alterar volumes do Docker com seguranca. A pasta local e configurada no host e aparece na aplicacao como /projects, sem copiar os arquivos.

Linux/macOS:
R_LAB_PROJECT_PATH=/caminho/do/projeto docker compose up -d

PowerShell:
$env:R_LAB_PROJECT_PATH = "C:/Users/seu-usuario/projeto"
docker compose up -d

No Windows, habilite a pasta no compartilhamento de arquivos do Docker Desktop. Se a pasta mudar, recrie o container para que o Compose aplique o novo volume. A aplicacao navega por subpastas, preserva a estrutura original e mostra scripts externos com o prefixo /projects.

A montagem padrao usa ./workspace em /projects. Para trabalhar com varios projetos, aponte R_LAB_PROJECT_PATH para uma pasta pai contendo os projetos. O acesso fica restrito a /workspace e /projects; nenhum socket do Docker e exposto.

## Sincronizacao de pacotes

Em Ambiente > Acoes rapidas, Sincronizar projeto procura renv.lock e DESCRIPTION no workspace e na pasta local montada. Sao considerados Packages do renv.lock e os campos Imports, Depends e LinkingTo do DESCRIPTION. O botao instala todos os pacotes identificados em um processo separado e mostra o log, sucesso ou falha.

A busca do CRAN fica em Resultados do CRAN. A consulta, os resultados e a selecao permanecem nessa aba; os pacotes selecionados podem ser enviados para instalacao em lote.

## Estados de execucao

Cada script e executado em um processo Rscript --vanilla independente. A interface atualiza automaticamente os estados Parado, Executando, Concluido, Falhou, Interrompido e Tempo excedido, registra stdout/stderr, codigo de saida, duracao e historico em logs/.

Os scripts externos usam /workspace como diretorio de trabalho, portanto devem usar caminhos relativos ao projeto e gravar resultados em output/ ou assets/ do workspace. Scripts R executam codigo arbitrario: use somente projetos confiaveis.


## Guia rapido: montar um projeto pessoal

A aba Scripts lista somente arquivos .R existentes na pasta montada em /projects. O diretorio interno /workspace contem a aplicacao e nao e usado como fonte de scripts.

1. Crie ou escolha uma pasta no computador para o projeto. Ela pode conter subpastas, DESCRIPTION, renv.lock, dados e scripts .R.
2. No Windows PowerShell, defina a pasta antes de iniciar:

   $env:R_LAB_PROJECT_PATH = "C:/Users/seu-usuario/Documents/meu-projeto"

   No Linux ou macOS:

   export R_LAB_PROJECT_PATH=/caminho/meu-projeto

3. Inicie o ambiente:

   docker compose up -d --build

4. Abra http://localhost:3838, entre em Scripts e navegue pela arvore de /projects.
5. Para refletir arquivos criados ou alterados no host, clique em Atualizar. Nao e necessario copiar arquivos nem reconstruir a imagem.
6. Se trocar a pasta montada, pare e recrie o servico:

   docker compose down
   docker compose up -d

Exemplo de estrutura:

    meu-projeto/
    |-- renv.lock
    |-- DESCRIPTION
    |-- dados/
    |-- scripts/
    |   |-- importar.R
    |   |-- analise/
    |       |-- modelo.R
    |-- output/

O script selecionado e executado com Rscript --vanilla usando a raiz do projeto montado como diretorio de trabalho. Assim, caminhos relativos como dados/entrada.csv continuam funcionando. No Windows, autorize a pasta no Docker Desktop em Settings > Resources > File Sharing.

A aplicacao nao acessa o Docker socket e nao permite escolher uma pasta arbitraria pelo navegador: o caminho precisa ser explicitamente autorizado no Compose por R_LAB_PROJECT_PATH.
