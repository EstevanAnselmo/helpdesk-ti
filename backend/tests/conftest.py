import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import models  # noqa: F401
from app.db.session import Base, get_db
from app.main import app

TEST_DATABASE_URL = "sqlite:///:memory:"


@pytest.fixture()
def client():
    engine = create_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        test_client.SessionLocal = TestingSessionLocal  # acesso direto ao banco de testes, quando necessário
        yield test_client
    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=engine)


def register_and_login(client, email="user@test.com", password="senha1234", name="Usuário Teste"):
    client.post("/api/auth/register", json={"name": name, "email": email, "password": password})
    resp = client.post("/api/auth/login", json={"email": email, "password": password})
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def make_staff(client, email="agente@empresa.com", password="senha1234", role="agent"):
    """Cria (ou promove) um usuário de suporte diretamente no banco de testes e retorna seus headers de auth."""
    from app.models.user import User

    headers = register_and_login(client, email=email, password=password, name="Agente Teste")
    db = client.SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).one()
        user.role = role
        db.commit()
    finally:
        db.close()
    # relogar para refletir o novo papel na sessão/token não é necessário: o papel é lido do banco a cada request.
    return headers
