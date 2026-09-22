from tests.conftest import mark_email_verified, register_and_login


def test_register_returns_serialized_user(client):
    resp = client.post(
        "/api/auth/register",
        json={
            "name": "Ana Silva",
            "email": "ana@empresa.com",
            "password": "senha1234",
        },
    )

    assert resp.status_code == 201

    body = resp.json()
    assert isinstance(body["message"], str)
    assert body["message"]

    user = body["user"]
    assert user["email"] == "ana@empresa.com"
    assert user["role"] == "user"
    assert user["email_verified"] is False
    assert "password" not in user
    assert "password_hash" not in user


def test_register_duplicate_email_returns_409(client):
    payload = {
        "name": "Ana",
        "email": "dup@empresa.com",
        "password": "senha1234",
    }

    first = client.post("/api/auth/register", json=payload)
    second = client.post("/api/auth/register", json=payload)

    assert first.status_code == 201
    assert second.status_code == 409


def test_register_rejects_weak_password(client):
    resp = client.post(
        "/api/auth/register",
        json={
            "name": "Ana",
            "email": "fraca@empresa.com",
            "password": "12345678",
        },
    )

    assert resp.status_code == 422


def test_login_requires_verified_email(client):
    client.post(
        "/api/auth/register",
        json={
            "name": "Bruno",
            "email": "naoverificado@empresa.com",
            "password": "senha1234",
        },
    )

    resp = client.post(
        "/api/auth/login",
        json={
            "email": "naoverificado@empresa.com",
            "password": "senha1234",
        },
    )

    assert resp.status_code == 403
    assert "confirmado" in resp.json()["detail"].lower()


def test_login_returns_token_and_user(client):
    email = "bruno@empresa.com"

    client.post(
        "/api/auth/register",
        json={
            "name": "Bruno",
            "email": email,
            "password": "senha1234",
        },
    )

    mark_email_verified(client, email)

    resp = client.post(
        "/api/auth/login",
        json={
            "email": email,
            "password": "senha1234",
        },
    )

    assert resp.status_code == 200

    body = resp.json()
    assert body["access_token"]
    assert body["token_type"] == "bearer"
    assert body["user"]["email"] == email
    assert body["user"]["email_verified"] is True


def test_login_wrong_password_returns_401(client):
    client.post(
        "/api/auth/register",
        json={
            "name": "Bruno",
            "email": "bruno2@empresa.com",
            "password": "senha1234",
        },
    )

    resp = client.post(
        "/api/auth/login",
        json={
            "email": "bruno2@empresa.com",
            "password": "errada123",
        },
    )

    assert resp.status_code == 401


def test_resend_verification_is_generic(client):
    resp = client.post(
        "/api/auth/resend-verification",
        json={"email": "qualquer@empresa.com"},
    )

    assert resp.status_code == 200
    assert isinstance(resp.json()["message"], str)
    assert resp.json()["message"]


def test_me_requires_token(client):
    resp = client.get("/api/auth/me")
    assert resp.status_code == 401


def test_me_returns_current_user(client):
    headers = register_and_login(
        client,
        email="carla@empresa.com",
    )

    resp = client.get(
        "/api/auth/me",
        headers=headers,
    )

    assert resp.status_code == 200
    assert resp.json()["email"] == "carla@empresa.com"
    assert resp.json()["email_verified"] is True
