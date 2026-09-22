import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import models  # noqa: F401
from app.db.session import Base, get_db
from app.main import app

TEST_DATABASE_URL = "sqlite:///:memory:"


@pytest.fixture(autouse=True)
def disable_real_verification_email(monkeypatch):
    """Evita envio de e-mail real durante a suíte de testes."""
    monkeypatch.setattr(
        "app.api.auth._issue_verification_email",
        lambda user: True,
    )


@pytest.fixture()
def client():
    engine = create_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(
        bind=engine,
        autoflush=False,
        autocommit=False,
    )
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        test_client.SessionLocal = TestingSessionLocal
        yield test_client

    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=engine)


def mark_email_verified(client, email: str) -> None:
    """Confirma o e-mail diretamente no banco de testes."""
    from app.models.user import User

    db = client.SessionLocal()
    try:
        user = db.query(User).filter(User.email == email.lower()).one()
        user.email_verified = True
        db.commit()
    finally:
        db.close()


def register_and_login(
    client,
    email="user@test.com",
    password="senha1234",
    name="Usuário Teste",
):
    register_response = client.post(
        "/api/auth/register",
        json={
            "name": name,
            "email": email,
            "password": password,
        },
    )
    assert register_response.status_code == 201, register_response.text

    mark_email_verified(client, email)

    login_response = client.post(
        "/api/auth/login",
        json={
            "email": email,
            "password": password,
        },
    )
    assert login_response.status_code == 200, login_response.text

    token = login_response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def make_staff(
    client,
    email="agente@empresa.com",
    password="senha1234",
    role="agent",
):
    """Cria/promove um usuário de suporte e retorna headers autenticados."""
    from app.models.user import User

    headers = register_and_login(
        client,
        email=email,
        password=password,
        name="Agente Teste",
    )

    db = client.SessionLocal()
    try:
        user = db.query(User).filter(User.email == email.lower()).one()
        user.role = role
        db.commit()
    finally:
        db.close()

    return headers
