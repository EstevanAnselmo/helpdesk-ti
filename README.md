# HelpDesk TI

Sistema de chamados e atendimento de TI desenvolvido com **Flutter**, **FastAPI** e **PostgreSQL**.

O projeto foi criado com foco em simular um sistema real de Help Desk, permitindo registrar, acompanhar e gerenciar chamados de suporte técnico, com autenticação, níveis de acesso, histórico de atendimento, comentários, atribuição de responsáveis, filtros e dashboard operacional.

## Visão geral

O HelpDesk TI permite organizar o fluxo completo de atendimento:

```text
Usuário identifica um problema
        ↓
Abre um chamado
        ↓
TI recebe e classifica
        ↓
Responsável é atribuído
        ↓
Atendimento é realizado
        ↓
Comentários e eventos são registrados
        ↓
Status é atualizado
        ↓
Chamado é resolvido
        ↓
Histórico permanece registrado
```

O sistema possui uma separação clara entre:

- **Dashboard:** visão operacional dos chamados.
- **Chamado:** atendimento individual.
- **Histórico:** registro das alterações e eventos ocorridos no chamado.
- **Relatórios:** análises agregadas que podem ser adicionadas futuramente.

## Tecnologias

### Frontend

- Flutter
- Dart
- Material Design
- Aplicação multiplataforma

### Backend

- Python
- FastAPI
- SQLAlchemy
- Pydantic
- JWT
- PostgreSQL
- Pytest

### Infraestrutura

- Docker
- Docker Compose

## Plataformas

O frontend foi estruturado para funcionar em diferentes plataformas:

- Windows
- Web
- Android
- iOS

O desenvolvimento e os testes podem ser realizados utilizando emuladores ou dispositivos físicos compatíveis.

## Funcionalidades

### Autenticação

- Login
- Cadastro de usuários
- Autenticação baseada em JWT
- Sessão persistida no aplicativo
- Controle de acesso por função

### Usuários e permissões

O sistema possui três papéis principais:

- `user`
- `agent`
- `admin`

Usuários comuns trabalham principalmente com os próprios chamados.

Usuários `agent` e `admin` possuem permissões ampliadas para gerenciamento dos atendimentos, como alteração de prioridade e atribuição de responsáveis.

### Chamados

- Criar chamado
- Visualizar chamados
- Buscar chamados
- Filtrar chamados
- Paginar resultados
- Alterar status
- Alterar prioridade
- Atribuir responsável
- Visualizar detalhes do chamado

### Histórico de atendimento

Cada chamado possui um histórico próprio para registrar os acontecimentos durante o atendimento.

Exemplos:

```text
Chamado criado
Comentário adicionado
Status alterado
Prioridade alterada
Responsável atribuído
```

Além do histórico automático de eventos, o chamado possui espaço para comentários e interação durante o atendimento.

### Dashboard

O dashboard apresenta uma visão geral dos chamados e permite acompanhar a situação atual da operação.

Os chamados podem ser acompanhados por status, como:

- 🟢 Novo
- 🟡 Pendente
- 🔵 Atribuído
- 🟠 Em atendimento
- ⚫ Resolvido

Os indicadores do dashboard podem ser utilizados para acessar rapidamente os chamados relacionados a cada situação.

## Estrutura do projeto

```text
helpdesk_ti_melhorado/
│
├── backend/
│   ├── app/
│   ├── tests/
│   ├── .env.example
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── requirements.txt
│
├── frontend/
│   ├── lib/
│   │   ├── models/
│   │   ├── screens/
│   │   ├── services/
│   │   └── main.dart
│   ├── android/
│   ├── ios/
│   ├── windows/
│   ├── web/
│   ├── pubspec.yaml
│   └── ...
│
├── flutter_src/
│   └── cópia de segurança do código Flutter original
│
├── README.md
└── CHANGELOG.md
```

> `frontend/` é o projeto Flutter oficial utilizado na aplicação. A pasta `flutter_src/` é mantida apenas como cópia de segurança do código fonte original.

## Subindo o backend com Docker

O modo recomendado para executar o projeto é utilizando Docker Compose.

No PowerShell:

```powershell
cd backend

copy .env.example .env

docker compose up -d --build
```

Verifique os containers:

```powershell
docker compose ps
```

O ambiente deverá iniciar:

```text
helpdesk-api
helpdesk-postgres
```

A API estará disponível em:

```text
http://127.0.0.1:8000
```

Documentação interativa:

```text
http://127.0.0.1:8000/docs
```

Health check:

```text
http://127.0.0.1:8000/health
```

Para visualizar os logs da API:

```powershell
docker compose logs api --tail=50
```

Para parar os containers:

```powershell
docker compose down
```

> Evite utilizar `docker compose down -v` normalmente, pois o parâmetro `-v` remove os volumes e pode apagar os dados do PostgreSQL utilizados no ambiente de desenvolvimento.

## Executando o Flutter

Entre na pasta do frontend:

```powershell
cd frontend
```

Instale as dependências:

```powershell
flutter pub get
```

Execute no Windows:

```powershell
flutter run -d windows
```

Execute no Chrome:

```powershell
flutter run -d chrome
```

Para verificar os dispositivos disponíveis:

```powershell
flutter devices
```

## Android

Para executar em um emulador Android:

```powershell
flutter emulators --launch HelpDesk_Pixel
```

Depois:

```powershell
flutter devices
```

Execute o aplicativo:

```powershell
flutter run -d emulator-5554
```

Quando o Android Emulator precisa acessar a API executada no Windows, `127.0.0.1` dentro do emulador não aponta para o computador host.

Nesse caso, utilize:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

## iOS

O projeto possui estrutura para iOS, porém o processo de build, assinatura e distribuição para iPhone depende do ambiente da Apple.

Normalmente é necessário:

- macOS
- Xcode
- configuração de assinatura Apple
- dispositivo físico ou simulador iOS

## Executando os testes

Os testes do backend utilizam Pytest.

```powershell
cd backend

pytest
```

Os testes automatizados utilizam SQLite em memória, portanto não dependem do PostgreSQL para sua execução.

Para analisar o código Flutter:

```powershell
cd frontend

flutter analyze
```

## Banco de dados

O projeto utiliza PostgreSQL.

Configuração padrão do ambiente Docker:

```text
Banco:    helpdesk
Usuário:  helpdesk
Senha:    helpdesk
Host:     localhost
Porta:     5432
```

Esses valores são destinados ao ambiente de desenvolvimento.

As configurações podem ser alteradas através do arquivo:

```text
backend/.env
```

## Primeiro usuário e roles

O cadastro de usuários pode ser realizado pela própria aplicação ou através da API:

```text
POST /api/auth/register
```

Novos usuários são criados inicialmente com o papel:

```text
user
```

Não existe um endpoint público para transformar um usuário em `admin` ou `agent`.

Para promover um usuário a administrador:

```powershell
cd backend

python -m scripts.promote_admin email@empresa.com
```

## Segurança

Antes de utilizar o projeto em um ambiente de produção, algumas medidas são necessárias.

### JWT

Defina uma chave forte para:

```text
JWT_SECRET
```

A chave deve ser armazenada no `.env` e nunca versionada no GitHub.

### HTTPS

Em produção, a API deve ser executada atrás de HTTPS.

### CORS

Configure:

```text
CORS_ORIGINS
```

somente com os domínios que realmente precisam acessar a API.

### Rate limiting

Recomenda-se implementar limitação de tentativas no endpoint de login para reduzir ataques de força bruta.

### Variáveis de ambiente

Informações sensíveis nunca devem ser armazenadas diretamente no código fonte.

Utilize:

```text
.env
```

e mantenha esse arquivo fora do Git.

## Banco e migrações

Atualmente o schema do banco é criado através do SQLAlchemy com:

```python
Base.metadata.create_all
```

O projeto ainda não utiliza Alembic.

Para um ambiente de produção, o próximo passo recomendado é implementar migrações versionadas com **Alembic**, principalmente antes de realizar alterações estruturais no banco.

## Arquitetura

A aplicação segue uma arquitetura separando frontend, API e banco de dados:

```text
┌─────────────────────────────┐
│          Flutter            │
│                             │
│ Web / Windows / Android     │
│ / iOS                       │
└──────────────┬──────────────┘
               │
               │ HTTP / REST
               ▼
┌─────────────────────────────┐
│          FastAPI            │
│                             │
│ Autenticação                │
│ Usuários                    │
│ Chamados                    │
│ Comentários                 │
│ Histórico                   │
│ Permissões                  │
└──────────────┬──────────────┘
               │
               │ SQLAlchemy
               ▼
┌─────────────────────────────┐
│         PostgreSQL          │
│                             │
│ Usuários                    │
│ Chamados                    │
│ Comentários                 │
│ Histórico                   │
└─────────────────────────────┘
```

## API

A documentação da API é gerada automaticamente pelo FastAPI.

Com o backend em execução:

```text
http://127.0.0.1:8000/docs
```

A interface Swagger permite testar os endpoints diretamente pelo navegador.

Entre os recursos disponíveis estão:

```text
/api/auth
/api/tickets
/api/users
/api/stats
```

O endpoint de histórico de atendimento também pode ser consultado pela API:

```text
GET /api/tickets/{ticket_id}/history
```

## Fluxo de desenvolvimento

Uma rotina básica para trabalhar no projeto:

### Backend

```powershell
cd backend

docker compose up -d --build

docker compose ps
```

### Frontend

Em outro terminal:

```powershell
cd frontend

flutter pub get

flutter run -d windows
```

### Validação

```powershell
cd frontend

flutter analyze
```

E no backend:

```powershell
cd backend

pytest
```

## Git

O projeto utiliza Git para controle de versão e está hospedado no GitHub:

**Repositório:**

https://github.com/EstevanAnselmo/helpdesk-ti

Exemplo de fluxo para registrar alterações:

```powershell
git status

git add .

git commit -m "Adiciona histórico aos atendimentos"

git push origin main
```

## Roadmap

Algumas evoluções planejadas para o projeto:

- [ ] Relatórios gerenciais
- [ ] SLA de atendimento
- [ ] Indicadores de tempo de resolução
- [ ] Anexos nos chamados
- [ ] Notificações
- [ ] Melhorias no sistema de permissões
- [ ] Alembic para migrações
- [ ] Filtros avançados
- [ ] Dashboard gerencial
- [ ] Integração com e-mail
- [ ] Integração com serviços externos
- [ ] Publicação em ambiente de produção

## Objetivo do projeto

O HelpDesk TI é um projeto pessoal de estudo e desenvolvimento, criado com o objetivo de aplicar conceitos utilizados em sistemas reais:

- desenvolvimento de APIs REST;
- autenticação e autorização;
- arquitetura cliente-servidor;
- persistência de dados;
- banco de dados relacional;
- desenvolvimento multiplataforma;
- testes automatizados;
- containerização;
- versionamento com Git;
- organização de código;
- evolução incremental de software.

O projeto continuará sendo evoluído conforme novas funcionalidades e melhorias forem implementadas.

## Licença

Este projeto foi desenvolvido para fins de estudo, aprendizado e evolução profissional.
