from tests.conftest import make_staff, register_and_login


def test_create_and_list_ticket(client):
    headers = register_and_login(client, email="user1@empresa.com")
    resp = client.post(
        "/api/tickets",
        json={"title": "Impressora não liga", "description": "Sem energia", "category": "Hardware"},
        headers=headers,
    )
    assert resp.status_code == 201
    ticket = resp.json()
    assert ticket["status"] == "open"
    assert ticket["priority"] == "medium"
    assert "email" not in ticket["creator"]  # UserPublic não expõe e-mail

    resp = client.get("/api/tickets", headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["total"] == 1
    assert body["items"][0]["title"] == "Impressora não liga"


def test_regular_user_cannot_see_others_tickets(client):
    headers_a = register_and_login(client, email="a@empresa.com")
    headers_b = register_and_login(client, email="b@empresa.com")
    client.post(
        "/api/tickets",
        json={"title": "Chamado do A", "description": "Descrição do chamado", "category": "Software"},
        headers=headers_a,
    )
    resp = client.get("/api/tickets", headers=headers_b)
    assert resp.json()["total"] == 0


def test_regular_user_cannot_change_priority_or_assignee(client):
    headers = register_and_login(client, email="user2@empresa.com")
    create = client.post(
        "/api/tickets",
        json={"title": "Chamado", "description": "Descrição válida", "category": "Rede"},
        headers=headers,
    )
    ticket_id = create.json()["id"]

    resp = client.patch(f"/api/tickets/{ticket_id}", json={"priority": "high"}, headers=headers)
    assert resp.status_code == 403

    resp = client.patch(f"/api/tickets/{ticket_id}", json={"assignee_id": 1}, headers=headers)
    assert resp.status_code == 403

    # mas pode fechar o próprio chamado
    resp = client.patch(f"/api/tickets/{ticket_id}", json={"status": "closed"}, headers=headers)
    assert resp.status_code == 200
    assert resp.json()["status"] == "closed"


def test_staff_can_assign_ticket_to_staff_member(client):
    user_headers = register_and_login(client, email="cliente@empresa.com")
    agent_headers = make_staff(client, email="agente1@empresa.com")

    create = client.post(
        "/api/tickets",
        json={"title": "Sem acesso ao sistema", "description": "Preciso de acesso urgente", "category": "Acesso"},
        headers=user_headers,
    )
    ticket_id = create.json()["id"]

    me = client.get("/api/auth/me", headers=agent_headers).json()
    resp = client.patch(f"/api/tickets/{ticket_id}", json={"assignee_id": me["id"]}, headers=agent_headers)
    assert resp.status_code == 200
    assert resp.json()["assignee_id"] == me["id"]


def test_assigning_to_non_staff_user_fails(client):
    user_headers = register_and_login(client, email="cliente2@empresa.com")
    other_user_headers = register_and_login(client, email="outro@empresa.com")
    agent_headers = make_staff(client, email="agente2@empresa.com")

    create = client.post(
        "/api/tickets",
        json={"title": "Outro chamado", "description": "Descrição válida aqui", "category": "Hardware"},
        headers=user_headers,
    )
    ticket_id = create.json()["id"]
    other_user = client.get("/api/auth/me", headers=other_user_headers).json()

    resp = client.patch(
        f"/api/tickets/{ticket_id}", json={"assignee_id": other_user["id"]}, headers=agent_headers
    )
    assert resp.status_code == 400


def test_filters_by_status_and_search(client):
    headers = register_and_login(client, email="filtros@empresa.com")
    client.post(
        "/api/tickets",
        json={"title": "Notebook lento", "description": "Está travando muito", "category": "Hardware"},
        headers=headers,
    )
    t2 = client.post(
        "/api/tickets",
        json={"title": "Erro no sistema", "description": "Tela azul ao abrir", "category": "Software"},
        headers=headers,
    ).json()
    client.patch(f"/api/tickets/{t2['id']}", json={"status": "resolved"}, headers=headers)

    resp = client.get("/api/tickets?status=resolved", headers=headers)
    assert resp.json()["total"] == 1
    assert resp.json()["items"][0]["title"] == "Erro no sistema"

    resp = client.get("/api/tickets?search=notebook", headers=headers)
    assert resp.json()["total"] == 1


def test_comments_flow(client):
    headers = register_and_login(client, email="comentario@empresa.com")
    ticket = client.post(
        "/api/tickets",
        json={"title": "Chamado com comentário", "description": "Descrição válida", "category": "Rede"},
        headers=headers,
    ).json()

    resp = client.post(
        f"/api/tickets/{ticket['id']}/comments", json={"content": "Já verifiquei o cabo de rede."}, headers=headers
    )
    assert resp.status_code == 201
    assert resp.json()["content"] == "Já verifiquei o cabo de rede."

    resp = client.get(f"/api/tickets/{ticket['id']}/comments", headers=headers)
    assert resp.status_code == 200
    assert len(resp.json()) == 1


def test_stats_summary(client):
    headers = register_and_login(client, email="stats@empresa.com")
    client.post(
        "/api/tickets",
        json={"title": "Chamado 1", "description": "Descrição válida", "category": "Hardware"},
        headers=headers,
    )
    resp = client.get("/api/tickets/stats/summary", headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["open"] == 1
    assert body["total"] == 1
