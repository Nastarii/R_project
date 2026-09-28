# AGENTS.md — R Lab

## 1. Objetivo

Criar um ambiente local para executar projetos R existentes, utilizando Docker e Shiny, com foco absoluto em **performance, imagem Docker pequena e facilidade de uso**.

O usuário deve conseguir montar seu ambiente, disponibilizar seu projeto R, instalar as bibliotecas necessárias, executar scripts e visualizar os resultados diretamente pelo navegador.

Evitar funcionalidades desnecessárias e dependências pesadas.

## 2. Tecnologias

* **R:** execução dos scripts.
* **Shiny:** interface web minimalista.
* **Docker:** ambiente isolado e portátil.
* **Docker Compose:** inicialização simplificada.
* **renv (opcional):** suporte a dependências por projeto, sem obrigatoriedade no MVP.
* **DT:** visualização de tabelas, somente quando necessário.

## 3. Docker e performance

Esta é a principal prioridade do projeto.

* Utilizar uma imagem base oficial do R, preferencialmente uma variante slim compatível.
* Minimizar o tamanho final da imagem.
* Instalar apenas dependências essenciais para executar R e Shiny.
* Evitar pacotes de sistema e bibliotecas R desnecessários.
* Aproveitar o cache de camadas do Docker.
* Limpar caches e arquivos temporários de instalação durante o build.
* Executar como usuário não root.
* Configurar volumes para disponibilizar projetos R existentes sem copiá-los para a imagem.
* Persistir as bibliotecas instaladas e os arquivos gerados.
* Evitar reconstruir a imagem sempre que o usuário alterar seus scripts.
* Configurar limites de memória e CPU de forma ajustável.
* Priorizar inicialização rápida e baixo consumo de memória em repouso.

O projeto R deve ser montado por volume Docker, permitindo que o usuário edite os arquivos no computador e execute as alterações imediatamente no ambiente.

## 4. Interface Shiny

Criar uma interface simples, leve e responsiva, com apenas duas sessões principais.

### Sessão 1 — Ambiente e pacotes

Apresentar informações gerais do ambiente:

* Versão do R instalada.
* Versão do Shiny.
* Diretório do projeto.
* Quantidade de pacotes instalados.

Gerenciamento de pacotes:

* Pesquisar pacotes no CRAN.
* Instalar pacotes pelo nome.
* Exibir pacotes instalados e suas versões.
* Atualizar ou remover pacotes.
* Exibir logs e progresso da instalação.

A instalação e atualização dos pacotes não devem bloquear a interface.

Utilizar um diretório persistente para as bibliotecas, evitando reinstalações após reiniciar o container.

### Sessão 2 — Execução e resultados

Criar uma interface para executar scripts de um projeto R já existente.

Funcionalidades:

* Selecionar um script `.R` disponível no diretório do projeto.
* Executar e interromper scripts.
* Exibir o estado da execução.
* Acompanhar logs e mensagens em tempo real.
* Exibir erros e avisos.
* Mostrar duração da execução.
* Listar os arquivos gerados.
* Visualizar imagens e tabelas produzidas.
* Permitir baixar os arquivos gerados.

Formatos iniciais suportados:

* **Tabelas:** CSV e TSV.
* **Imagens:** PNG e JPEG.
* **Logs:** texto e mensagens de execução.
* **Outros arquivos:** disponibilizar download.

A interface deve atualizar os logs e resultados sem recarregar a página inteira.

## 5. Execução dos scripts

* Executar scripts em processos R independentes da aplicação Shiny.
* Permitir que a interface continue responsiva durante a execução.
* Capturar `stdout`, `stderr`, avisos, erros e código de saída.
* Exibir o progresso por meio de logs.
* Permitir interromper uma execução.
* Utilizar o diretório do projeto como diretório de trabalho.
* Disponibilizar um diretório de saída para os resultados.
* Manter os arquivos gerados disponíveis após a reinicialização do container.

Evitar execução simultânea de múltiplos scripts no MVP, salvo se a implementação puder garantir isolamento e controle de recursos sem aumentar significativamente a complexidade.

## 6. Estrutura do projeto

Manter uma estrutura pequena e modular:

```text
r-lab/
├── app/
│   ├── app.R
│   ├── modules/
│   │   ├── environment.R
│   │   └── execution.R
│   ├── services/
│   │   ├── package_manager.R
│   │   ├── script_runner.R
│   │   └── result_viewer.R
│   └── www/
│       └── style.css
├── docker/
│   └── Dockerfile
├── workspace/
│   └── .gitkeep
├── docker-compose.yml
├── .dockerignore
├── .gitignore
└── README.md
```

O diretório `workspace` será montado como volume, permitindo utilizar projetos R existentes.

## 7. Docker Compose

Configurar um único serviço principal contendo R e Shiny.

Requisitos:

* Inicialização com `docker compose up -d`.
* Interface acessível pelo navegador na porta `3838`.
* Porta configurável por variável de ambiente.
* Montagem do projeto local em `/workspace`.
* Diretório persistente para pacotes R.
* Diretório persistente para logs e resultados.
* Reinicialização automática em caso de falha.
* Healthcheck simples.
* Configuração de recursos ajustável.

Não adicionar banco de dados, filas, serviços auxiliares ou infraestrutura externa no MVP.

## 8. Interface visual

* Design minimalista e moderno.
* Duas abas principais: **Ambiente** e **Executar scripts**.
* Tema claro, com opção de tema escuro.
* Navegação simples e poucos elementos visuais.
* Feedback claro para instalação, execução, erros e conclusão.
* Layout responsivo.
* Evitar animações, componentes pesados e gráficos desnecessários.

## 9. Segurança e estabilidade

* Executar como usuário não root.
* Não expor o Docker socket.
* Restringir a aplicação ao projeto montado e aos diretórios necessários.
* Não permitir acesso arbitrário ao sistema de arquivos do host.
* Permitir configurar limites de memória e tempo de execução.
* Tratar erros sem encerrar a aplicação Shiny.
* Documentar que scripts R executam código arbitrário e devem ser confiáveis.

## 10. Diretrizes de implementação

* Priorizar a menor imagem Docker funcional possível.
* Medir o tamanho da imagem e o consumo de memória.
* Não adicionar funcionalidades fora do escopo inicial.
* Não criar editor de código, dashboard avançado ou sistema de gerenciamento de projetos.
* Não instalar bibliotecas R desnecessárias na imagem.
* Manter a instalação de pacotes independente do build da imagem.
* Utilizar módulos Shiny pequenos e independentes.
* Evitar dependências adicionais quando o R base já oferece a funcionalidade necessária.
* Garantir que a alteração de scripts locais não exija rebuild do container.
* Documentar os comandos para iniciar, parar, atualizar e acessar o ambiente.

## 11. Critérios de conclusão

1. Imagem Docker enxuta e com build reproduzível.
2. Ambiente iniciado com um único comando.
3. Acesso à interface Shiny pelo navegador.
4. Exibição da versão do R e dos pacotes instalados.
5. Instalação e atualização de pacotes pela interface.
6. Execução de scripts R existentes no diretório montado.
7. Acompanhamento de logs e erros sem bloquear a interface.
8. Visualização de tabelas e imagens geradas.
9. Persistência de bibliotecas, logs e resultados.
10. Baixo consumo de recursos e inicialização rápida.

**Prioridade máxima:** performance, imagem Docker mínima, simplicidade de configuração e execução prática de projetos R existentes. Toda funcionalidade que não contribua diretamente para esses objetivos deve ficar fora da versão inicial.
