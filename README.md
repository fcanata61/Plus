# PLUS – Gerenciador de Pacotes Avançado para Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

PLUS é um **gerenciador de pacotes avançado para Linux** escrito em **Shell Script**, inspirado em sistemas como LFS e Portage. Ele permite gerenciar dependências, builds isolados, patches, SHA256, sync de repositórios Git/HTTP e toolchain completo, tudo configurável via `plus.conf`.

---

## Características Principais

- Gerenciamento avançado de dependências (obrigatórias, opcionais, recomendadas)  
- Build isolado de pacotes, com `destdir` e `fakeroot`  
- Aplicação automática de patches  
- Instalação, remoção e upgrade de pacotes  
- Detecta pacotes órfãos e suporta undo de instalação  
- SHA256 para verificação e geração de arquivos  
- Sync de pacotes via Git ou HTTP/HTTPS em diretório dedicado  
- Hooks pre/post para cada etapa (build, install, remove, sync, upgrade)  
- Logs detalhados de todas as operações  
- Configuração completa via `plus.conf`  
- Suporte a toolchain para Linux From Scratch (LFS)
