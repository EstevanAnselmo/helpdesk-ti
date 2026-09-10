def test_register_returns_serialized_user(client):
    resp = client.post(
        "/api/auth/register",
        json={"name": "Ana Silva", "email": "ana@empresa.com", "password": "senha1234"},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["email"] == "ana@empresa.com"
    assert body["role"] == "user"
    assert "password" not in body
    assert "password_hash" not in body


def test_register_duplicate_email_returns_409(client):
    payload = {"name": "Ana", "email": "dup@empresa.com", "password": "senha1234"}
    client.post("/api/auth/register", json=payload)
    resp = client.post("/api/auth/register", json=payload)
    assert resp.status_code == 409


def test_register_rejects_weak_password(client):
    resp = client.post(
        "/api/auth/register",
        json={"name": "Ana", "email": "fraca@empresa.com", "password": "12345678"},
    )
    assert resp.status_code == 422


def test_login_returns_token_and_user(client):
    client.post(
        "/api/auth/register",
        json={"name": "Bruno", "email": "bruno@empresa.com", "password": "senha1234"},
    )
    resp = client.post("/api/auth/login", json={"email": "bruno@empresa.com", "password": "senha1234"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["access_token"]
    assert body["user"]["email"] == "bruno@empresa.com"


def test_login_wrong_password_returns_401(client):
    client.post(
        "/api/auth/register",
        json={"name": "Bruno", "email": "bruno2@empresa.com", "password": "senha1234"},
    )
    resp = client.post("/api/auth/login", json={"email": "bruno2@empresa.com", "password": "errada123"})
    assert resp.status_code == 401


def test_me_requires_token(client):
    resp = client.get("/api/auth/me")
    assert resp.status_code == 401


def test_me_returns_current_user(client):
    from tests.conftest import register_and_login

    headers = register_and_login(client, email="carla@empresa.com")
    resp = client.get("/api/auth/me", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["email"] == "carla@empresa.com"
