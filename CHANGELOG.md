# Changelog — protótipo → v1.1

## 🐛 Bug crítico corrigido

- **`UserOut` sem `from_attributes=True`**: o schema de resposta de usuário
  não conseguia serializar objetos vindos do banco (SQLAlchemy). Na prática,
  isso quebrava `/auth/register`, `/auth/login` e `/auth/me` com erro 500.
  `TicketOut` já tinha essa configuração — só faltava em `UserOut`.

## 🔐 Backend — segurança e regras de negócio

- Papéis (`user`/`agent`/`admin`), status e prioridade agora são **Enums**
  reais no banco e na API, em vez de strings soltas sem validação.
- Regra de acesso corrigida/reforçada: usuário comum só vê e só fecha os
  próprios chamados; só `agent`/`admin` mudam prioridade e atribuem
  responsável; atribuir a alguém que não é da equipe de suporte agora é
  bloqueado (antes não existia essa checagem).
- Cadastro com e-mail duplicado agora responde `409` de forma limpa, com
  `try/except IntegrityError`, em vez de deixar a exceção do banco vazar.
- Senha exige 8+ caracteres combinando letras e números (era só "6+ caracteres").
- `JWT_SECRET` padrão agora **bloqueia a subida da API** se `ENVIRONMENT=production`,
  e emite aviso em desenvolvimento.
- Handlers globais de exceção — erros inesperados não vazam stacktrace para o
  cliente, e ficam logados no servidor.
- `/health` agora também testa a conexão com o banco.
- Endpoint `/auth/refresh` para renovar o token sem precisar logar de novo.

## ✨ Backend — funcionalidades novas

- **Comentários/histórico por chamado** (`GET`/`POST /tickets/{id}/comments`).
- **Filtros, busca e paginação** em `GET /tickets` (status, prioridade,
  categoria, texto livre, "somente meus chamados", `skip`/`limit`).
- **Listagem de usuários** (`GET /users`) para alimentar o seletor de
  responsável no app — antes não havia como saber quem podia ser atribuído.
- Script `scripts/promote_admin.py` para promover o primeiro admin (não existe
  endpoint HTTP para isso, de propósito).
- **Testes automatizados** (`pytest`, SQLite em memória) cobrindo auth,
  permissões, filtros, atribuição e comentários — o protótipo não tinha
  nenhum teste.
- **Dockerfile** da API + `docker-compose.yml` agora sobe API e banco juntos
  (antes só o Postgres era containerizado).

## 📱 Flutter — funcionalidades novas

- **Tela de cadastro** — o protótipo tinha o endpoint no backend mas nenhuma
  tela para usá-lo.
- **Sessão persistida** (`shared_preferences`): fechar e reabrir o app não
  pede login de novo, e o token expirado devolve o usuário à tela de login
  automaticamente (inclusive vindo de uma tela profunda de navegação).
- **Logout** (não existia).
- **Tela de detalhe do chamado**: mudar status, e para agentes/admins,
  também prioridade e responsável, além de ver e adicionar comentários.
- **Filtros e busca** na listagem de chamados, com paginação.
- Base URL da API configurável via `--dart-define=API_BASE_URL=...` (antes
  fixa em `127.0.0.1`, o que não funciona em emulador Android nem dispositivo físico).

## 🧹 Reorganização

- `main.dart` (antes um arquivo único com tudo) foi dividido em
  `screens/auth`, `screens/dashboard`, `screens/tickets` e `widgets` — pastas
  que já existiam vazias no protótipo, sinalizando essa intenção.
- Modelos Dart ganharam `creator`/`assignee` aninhados (o backend já manda
  esses dados; o app simplesmente não os usava).

## ⚠️ O que ainda fica para uma próxima etapa

- Migrações versionadas com Alembic (hoje o schema é criado via `create_all`).
- Rate limiting no login (mitigar força bruta).
- Anexos/upload de arquivos nos chamados.
- Notificações (push ou e-mail) quando um chamado muda de status.
- Testes automatizados no lado Flutter (widget/integration tests).
