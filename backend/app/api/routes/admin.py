"""Admin API routes for user management and system stats."""

import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.dependencies import get_db_session
from app.core.security import get_current_user
from app.models.user import User
from app.models.task import Task
from app.models.submission import Submission
from app.models.ledger import TanLedger
from app.models.family import Family, FamilyMember

router = APIRouter()
logger = logging.getLogger(__name__)


# --- Schemas ---

class UserAdminRead(BaseModel):
    id: int
    name: str
    email: Optional[str]
    role: str
    email_verified: bool
    is_active: bool
    created_at: datetime
    family_count: int = 0

    class Config:
        from_attributes = True


class StatsResponse(BaseModel):
    users_total: int
    users_parents: int
    users_children: int
    users_pending_verification: int
    families_total: int
    tasks_total: int
    tasks_active: int
    submissions_total: int
    submissions_pending: int
    submissions_approved: int
    tan_entries_total: int
    minutes_earned_total: int


class LogEntry(BaseModel):
    timestamp: datetime
    type: str
    message: str
    user_id: Optional[int] = None
    user_name: Optional[str] = None


class MessageResponse(BaseModel):
    message: str
    success: bool = True


# --- Helper ---

def require_admin(user: User = Depends(get_current_user)) -> User:
    """Require admin role (currently any parent is admin)."""
    if user.role != "parent":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin-Rechte erforderlich"
        )
    return user


# --- Endpoints ---

@router.get("/users", response_model=list[UserAdminRead])
def list_users(
    role: Optional[str] = Query(None, description="Filter by role"),
    verified: Optional[bool] = Query(None, description="Filter by verification status"),
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """List all users with their status."""
    query = db.query(User)

    if role:
        query = query.filter(User.role == role)
    if verified is not None:
        query = query.filter(User.email_verified == verified)

    users = query.order_by(User.created_at.desc()).all()

    result = []
    for user in users:
        family_count = db.query(FamilyMember).filter(FamilyMember.user_id == user.id).count()
        result.append(UserAdminRead(
            id=user.id,
            name=user.name,
            email=user.email,
            role=user.role,
            email_verified=user.email_verified,
            is_active=user.is_active,
            created_at=user.created_at,
            family_count=family_count,
        ))

    return result


@router.post("/users/{user_id}/verify", response_model=MessageResponse)
def verify_user(
    user_id: int,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Manually verify a user's email."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User nicht gefunden")

    if user.email_verified:
        return MessageResponse(message=f"User {user.name} ist bereits verifiziert")

    user.email_verified = True
    user.verification_token = None
    db.commit()

    logger.info(f"Admin {admin.id} verified user {user_id}")
    return MessageResponse(message=f"User {user.name} wurde verifiziert")


@router.post("/users/{user_id}/toggle-active", response_model=MessageResponse)
def toggle_user_active(
    user_id: int,
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Toggle user active status."""
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User nicht gefunden")

    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="Kann eigenen Account nicht deaktivieren")

    user.is_active = not user.is_active
    db.commit()

    status_text = "aktiviert" if user.is_active else "deaktiviert"
    logger.info(f"Admin {admin.id} toggled user {user_id} to {status_text}")
    return MessageResponse(message=f"User {user.name} wurde {status_text}")


@router.get("/stats", response_model=StatsResponse)
def get_stats(
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Get system statistics."""
    # User stats
    users_total = db.query(User).count()
    users_parents = db.query(User).filter(User.role == "parent").count()
    users_children = db.query(User).filter(User.role == "child").count()
    users_pending = db.query(User).filter(
        User.email_verified == False,
        User.email.isnot(None)
    ).count()

    # Family stats
    families_total = db.query(Family).filter(Family.is_active == True).count()

    # Task stats
    tasks_total = db.query(Task).count()
    tasks_active = db.query(Task).filter(Task.is_active == True).count()

    # Submission stats
    submissions_total = db.query(Submission).count()
    submissions_pending = db.query(Submission).filter(Submission.status == "pending").count()
    submissions_approved = db.query(Submission).filter(Submission.status == "approved").count()

    # TAN stats
    tan_entries_total = db.query(TanLedger).count()
    minutes_result = db.query(func.sum(TanLedger.minutes)).scalar()
    minutes_earned_total = minutes_result or 0

    return StatsResponse(
        users_total=users_total,
        users_parents=users_parents,
        users_children=users_children,
        users_pending_verification=users_pending,
        families_total=families_total,
        tasks_total=tasks_total,
        tasks_active=tasks_active,
        submissions_total=submissions_total,
        submissions_pending=submissions_pending,
        submissions_approved=submissions_approved,
        tan_entries_total=tan_entries_total,
        minutes_earned_total=minutes_earned_total,
    )


@router.get("/logs", response_model=list[LogEntry])
def get_logs(
    limit: int = Query(50, le=200),
    db: Session = Depends(get_db_session),
    admin: User = Depends(require_admin),
):
    """Get recent activity logs (based on submissions and user registrations)."""
    logs = []

    # Recent registrations
    recent_users = db.query(User).order_by(User.created_at.desc()).limit(limit // 2).all()
    for user in recent_users:
        logs.append(LogEntry(
            timestamp=user.created_at,
            type="registration",
            message=f"Neuer User registriert: {user.name} ({user.role})",
            user_id=user.id,
            user_name=user.name,
        ))

    # Recent submissions
    recent_subs = db.query(Submission).order_by(Submission.created_at.desc()).limit(limit // 2).all()
    for sub in recent_subs:
        child = db.get(User, sub.child_id)
        task = db.get(Task, sub.task_id)
        child_name = child.name if child else f"User {sub.child_id}"
        task_title = task.title if task else f"Task {sub.task_id}"

        if sub.status == "pending":
            msg = f"{child_name} hat '{task_title}' eingereicht"
        elif sub.status == "approved":
            msg = f"'{task_title}' von {child_name} wurde genehmigt"
        elif sub.status == "rejected":
            msg = f"'{task_title}' von {child_name} wurde abgelehnt"
        else:
            msg = f"Submission von {child_name}: {sub.status}"

        logs.append(LogEntry(
            timestamp=sub.created_at,
            type=f"submission_{sub.status}",
            message=msg,
            user_id=sub.child_id,
            user_name=child_name,
        ))

    # Sort by timestamp
    logs.sort(key=lambda x: x.timestamp, reverse=True)
    return logs[:limit]


# --- Admin UI ---

ADMIN_HTML = """
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ZeitSchatz Admin</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1a2e; color: #eee; padding: 20px;
        }
        h1 { color: #4CAF50; margin-bottom: 20px; }
        h2 { color: #64b5f6; margin: 20px 0 10px; border-bottom: 1px solid #333; padding-bottom: 5px; }
        .container { max-width: 1200px; margin: 0 auto; }
        .login-form {
            background: #16213e; padding: 30px; border-radius: 8px;
            max-width: 400px; margin: 50px auto;
        }
        .login-form input {
            width: 100%; padding: 12px; margin: 10px 0;
            border: 1px solid #333; border-radius: 4px;
            background: #0f0f23; color: #eee;
        }
        .login-form button {
            width: 100%; padding: 12px; background: #4CAF50;
            color: white; border: none; border-radius: 4px; cursor: pointer;
            font-size: 16px; margin-top: 10px;
        }
        .login-form button:hover { background: #45a049; }
        .stats-grid {
            display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px; margin-bottom: 20px;
        }
        .stat-card {
            background: #16213e; padding: 20px; border-radius: 8px; text-align: center;
        }
        .stat-value { font-size: 2em; font-weight: bold; color: #4CAF50; }
        .stat-label { color: #888; margin-top: 5px; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #333; }
        th { background: #16213e; color: #64b5f6; }
        tr:hover { background: #1a1a3e; }
        .badge {
            padding: 3px 8px; border-radius: 12px; font-size: 0.8em;
        }
        .badge-success { background: #4CAF50; color: white; }
        .badge-warning { background: #ff9800; color: black; }
        .badge-danger { background: #f44336; color: white; }
        .badge-info { background: #2196F3; color: white; }
        button.action {
            padding: 5px 10px; border: none; border-radius: 4px;
            cursor: pointer; margin-right: 5px;
        }
        button.verify { background: #4CAF50; color: white; }
        button.toggle { background: #ff9800; color: black; }
        .log-entry { padding: 10px; border-bottom: 1px solid #333; }
        .log-time { color: #888; font-size: 0.9em; }
        .log-type {
            display: inline-block; padding: 2px 6px; border-radius: 4px;
            font-size: 0.8em; margin-right: 10px;
        }
        .hidden { display: none; }
        .error { color: #f44336; margin: 10px 0; }
        .tabs { display: flex; gap: 10px; margin-bottom: 20px; }
        .tab {
            padding: 10px 20px; background: #16213e; border: none;
            color: #888; cursor: pointer; border-radius: 4px;
        }
        .tab.active { background: #4CAF50; color: white; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        .refresh-btn {
            background: #2196F3; color: white; border: none;
            padding: 8px 16px; border-radius: 4px; cursor: pointer;
            margin-bottom: 15px;
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Login Form -->
        <div id="loginSection" class="login-form">
            <h1>ZeitSchatz Admin</h1>
            <input type="email" id="email" placeholder="Email">
            <input type="password" id="password" placeholder="Passwort">
            <div id="loginError" class="error hidden"></div>
            <button onclick="login()">Anmelden</button>
        </div>

        <!-- Dashboard -->
        <div id="dashboard" class="hidden">
            <h1>ZeitSchatz Admin Dashboard</h1>
            <button class="refresh-btn" onclick="loadAll()">Aktualisieren</button>

            <div class="tabs">
                <button class="tab active" onclick="showTab('stats')">Statistiken</button>
                <button class="tab" onclick="showTab('users')">Benutzer</button>
                <button class="tab" onclick="showTab('logs')">Aktivitaeten</button>
            </div>

            <!-- Stats Tab -->
            <div id="statsTab" class="tab-content active">
                <h2>System-Statistiken</h2>
                <div id="statsGrid" class="stats-grid"></div>
            </div>

            <!-- Users Tab -->
            <div id="usersTab" class="tab-content">
                <h2>Benutzer</h2>
                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Email</th>
                            <th>Rolle</th>
                            <th>Status</th>
                            <th>Familien</th>
                            <th>Aktionen</th>
                        </tr>
                    </thead>
                    <tbody id="usersTable"></tbody>
                </table>
            </div>

            <!-- Logs Tab -->
            <div id="logsTab" class="tab-content">
                <h2>Letzte Aktivitaeten</h2>
                <div id="logsList"></div>
            </div>
        </div>
    </div>

    <script>
        let token = localStorage.getItem('adminToken');
        const API = window.location.origin;

        // Check if already logged in
        if (token) {
            showDashboard();
        }

        async function login() {
            const email = document.getElementById('email').value;
            const password = document.getElementById('password').value;
            const errorDiv = document.getElementById('loginError');

            try {
                const res = await fetch(`${API}/auth/login/email`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email, password })
                });

                if (!res.ok) {
                    const err = await res.json();
                    throw new Error(err.detail || 'Login fehlgeschlagen');
                }

                const data = await res.json();
                token = data.access_token;
                localStorage.setItem('adminToken', token);
                showDashboard();
            } catch (e) {
                errorDiv.textContent = e.message;
                errorDiv.classList.remove('hidden');
            }
        }

        function showDashboard() {
            document.getElementById('loginSection').classList.add('hidden');
            document.getElementById('dashboard').classList.remove('hidden');
            loadAll();
        }

        async function api(endpoint) {
            const res = await fetch(`${API}${endpoint}`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (res.status === 401) {
                localStorage.removeItem('adminToken');
                location.reload();
            }
            return res.json();
        }

        async function apiPost(endpoint) {
            const res = await fetch(`${API}${endpoint}`, {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${token}` }
            });
            return res.json();
        }

        async function loadAll() {
            await Promise.all([loadStats(), loadUsers(), loadLogs()]);
        }

        async function loadStats() {
            const stats = await api('/admin/stats');
            const grid = document.getElementById('statsGrid');
            grid.innerHTML = `
                <div class="stat-card"><div class="stat-value">${stats.users_total}</div><div class="stat-label">Benutzer gesamt</div></div>
                <div class="stat-card"><div class="stat-value">${stats.users_parents}</div><div class="stat-label">Eltern</div></div>
                <div class="stat-card"><div class="stat-value">${stats.users_children}</div><div class="stat-label">Kinder</div></div>
                <div class="stat-card"><div class="stat-value">${stats.users_pending_verification}</div><div class="stat-label">Warten auf Verifizierung</div></div>
                <div class="stat-card"><div class="stat-value">${stats.families_total}</div><div class="stat-label">Familien</div></div>
                <div class="stat-card"><div class="stat-value">${stats.tasks_active}</div><div class="stat-label">Aktive Aufgaben</div></div>
                <div class="stat-card"><div class="stat-value">${stats.submissions_pending}</div><div class="stat-label">Offene Einreichungen</div></div>
                <div class="stat-card"><div class="stat-value">${stats.minutes_earned_total}</div><div class="stat-label">Minuten verdient</div></div>
            `;
        }

        async function loadUsers() {
            const users = await api('/admin/users');
            const tbody = document.getElementById('usersTable');
            tbody.innerHTML = users.map(u => `
                <tr>
                    <td>${u.id}</td>
                    <td>${u.name}</td>
                    <td>${u.email || '-'}</td>
                    <td><span class="badge ${u.role === 'parent' ? 'badge-info' : 'badge-success'}">${u.role}</span></td>
                    <td>
                        ${u.email_verified ? '<span class="badge badge-success">Verifiziert</span>' : '<span class="badge badge-warning">Ausstehend</span>'}
                        ${u.is_active ? '' : '<span class="badge badge-danger">Inaktiv</span>'}
                    </td>
                    <td>${u.family_count}</td>
                    <td>
                        ${!u.email_verified && u.email ? `<button class="action verify" onclick="verifyUser(${u.id})">Verifizieren</button>` : ''}
                        <button class="action toggle" onclick="toggleUser(${u.id})">${u.is_active ? 'Deaktivieren' : 'Aktivieren'}</button>
                    </td>
                </tr>
            `).join('');
        }

        async function loadLogs() {
            const logs = await api('/admin/logs?limit=50');
            const list = document.getElementById('logsList');
            list.innerHTML = logs.map(log => {
                const typeClass = log.type.includes('approved') ? 'badge-success' :
                                  log.type.includes('rejected') ? 'badge-danger' :
                                  log.type.includes('registration') ? 'badge-info' : 'badge-warning';
                const time = new Date(log.timestamp).toLocaleString('de-DE');
                return `
                    <div class="log-entry">
                        <span class="log-time">${time}</span>
                        <span class="log-type badge ${typeClass}">${log.type}</span>
                        ${log.message}
                    </div>
                `;
            }).join('');
        }

        async function verifyUser(id) {
            await apiPost(`/admin/users/${id}/verify`);
            loadUsers();
        }

        async function toggleUser(id) {
            await apiPost(`/admin/users/${id}/toggle-active`);
            loadUsers();
        }

        function showTab(name) {
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
            document.querySelector(`.tab[onclick="showTab('${name}')"]`).classList.add('active');
            document.getElementById(`${name}Tab`).classList.add('active');
        }
    </script>
</body>
</html>
"""


@router.get("/", response_class=HTMLResponse)
def admin_ui():
    """Serve the admin dashboard UI."""
    return ADMIN_HTML
