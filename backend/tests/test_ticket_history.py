from tests.conftest import make_staff, register_and_login


def test_ticket_history_records_creation_and_status_change(client):
    headers = register_and_login(client, email="history@empresa.com")

    created = client.post(
        "/api/tickets",
        json={
            "title": "Notebook com problema",
            "description": "O equipamento não liga.",
            "category": "Hardware",
        },
        headers=headers,
    )
    assert created.status_code == 201
    ticket_id = created.json()["id"]

    updated = client.patch(
        f"/api/tickets/{ticket_id}",
        json={"status": "in_progress"},
        headers=headers,
    )
    assert updated.status_code == 200

    history = client.get(f"/api/tickets/{ticket_id}/history", headers=headers)
    assert history.status_code == 200
    body = history.json()

    assert len(body) == 2
    assert body[0]["action"] == "created"
    assert body[1]["action"] == "status_changed"
    assert body[1]["old_value"] == "open"
    assert body[1]["new_value"] == "in_progress"


def test_ticket_history_records_priority_assignment_and_comment(client):
    user_headers = register_and_login(client, email="history-user@empresa.com")
    agent_headers = make_staff(client, email="history-agent@empresa.com")

    created = client.post(
        "/api/tickets",
        json={
            "title": "Acesso ao sistema",
            "description": "Usuário sem acesso.",
            "category": "Acesso",
        },
        headers=user_headers,
    )
    ticket_id = created.json()["id"]

    agent = client.get("/api/auth/me", headers=agent_headers).json()

    response = client.patch(
        f"/api/tickets/{ticket_id}",
        json={"priority": "high", "assignee_id": agent["id"]},
        headers=agent_headers,
    )
    assert response.status_code == 200

    response = client.post(
        f"/api/tickets/{ticket_id}/comments",
        json={"content": "Vou verificar o acesso."},
        headers=agent_headers,
    )
    assert response.status_code == 201

    history = client.get(f"/api/tickets/{ticket_id}/history", headers=agent_headers)
    assert history.status_code == 200
    actions = [item["action"] for item in history.json()]

    assert actions == [
        "created",
        "priority_changed",
        "assignee_changed",
        "comment_added",
    ]
