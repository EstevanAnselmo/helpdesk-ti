# HelpDesk TI

Sistema de chamados de TI — Flutter + FastAPI + PostgreSQL.

> Este projeto partiu de um protótipo funcional e foi revisado/expandido:
> correção de um bug crítico de serialização, papéis e permissões reais,
> comentários por chamado, filtros/busca/paginação, sessão persistida no
> app, tela de cadastro, tela de detalhe do chamado, testes automatizados
> do backend e containerização completa. Veja `CHANGELOG.md` para a lista
> detalhada do que mudou em relação ao protótipo original.

## Estrutura

- `flutter/`: aplicativo Flutter (login, cadastro, dashboard, chamados, detalhe/comentários).
- `backend/`: API FastAPI + SQLAlchemy + PostgreSQL.
- `backend/tests/`: testes automatizados (pytest).
- `backend/docker-compose.yml`: sobe Postgres **e** a API.

## Subindo tudo com Docker (recomendado)

```bash
cd backend
cp .env.example .env   # no Windows: copy .env.example .env
docker compose up -d --build
```

API disponível em `http://127.0.0.1:8000` — documentação interativa em `http://127.0.0.1:8000/docs`.

## Rodando o backend manualmente (sem Docker para a API)

```bash
cd backend
cp .env.example .env
docker compose up -d postgres   # só o banco
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Rodando os testes

```bash
cd backend
pip install -r requirements.txt
pytest
```

Os testes usam SQLite em memória — não precisam do Postgres nem do `.env` configurado.

## Flutter

```bash
cd flutter
flutter pub get
flutter run -d windows
# Rodando em outro dispositivo/emulador, aponte para a API certa:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

## Banco

PostgreSQL em `localhost:5432`:

- Banco: `helpdesk`
- Usuário: `helpdesk`
- Senha: `helpdesk`

> Não há Alembic configurado — o schema é criado via `Base.metadata.create_all`
> na subida da API. Para produção de verdade, o próximo passo recomendado é
> migrar para Alembic antes da primeira alteração de schema em produção.

## Primeiro usuário e papéis (roles)

Qualquer pessoa pode se cadastrar (tela "Cadastre-se" no app, ou `POST /api/auth/register`) —
todo cadastro novo nasce com o papel `user`. Não existe endpoint público para
virar `admin`/`agent` (de propósito, por segurança). Para promover alguém:

```bash
cd backend
python -m scripts.promote_admin email@empresa.com
```

Usuários com papel `agent` ou `admin` enxergam todos os chamados, podem mudar
prioridade e atribuir responsável; usuários comuns só veem e atuam nos
próprios chamados (podem alterar o status do que abriram, por ex. fechar).

## Segurança — antes de ir para produção

- Defina um `JWT_SECRET` forte no `.env` (a API recusa subir com o valor
  padrão se `ENVIRONMENT=production`).
- Sirva atrás de HTTPS e ajuste `CORS_ORIGINS` para os domínios reais.
- Adicione rate limiting no `/auth/login` (não incluído aqui) para mitigar
  força bruta.
- Considere Alembic para migrações versionadas de schema.
