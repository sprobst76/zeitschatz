"""add allowed_devices, target_devices, selected_device

Revision ID: 0005_device_changes
Revises: 0004_add_tan_reward
Create Date: 2025-12-20
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0005_device_changes"
down_revision = "0004_add_tan_reward"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)

    # Users: add allowed_devices
    user_columns = {col["name"] for col in inspector.get_columns("users")}
    if "allowed_devices" not in user_columns:
        op.add_column("users", sa.Column("allowed_devices", sa.JSON(), nullable=True))

    # Tasks: rename target_device to target_devices (JSON list)
    task_columns = {col["name"] for col in inspector.get_columns("tasks")}
    if "target_device" in task_columns and "target_devices" not in task_columns:
        # SQLite doesn't support column rename directly, so we add new and migrate
        op.add_column("tasks", sa.Column("target_devices", sa.JSON(), nullable=True))
        # Migrate existing data: convert single device to list
        op.execute("""
            UPDATE tasks
            SET target_devices = json_array(target_device)
            WHERE target_device IS NOT NULL AND target_device != ''
        """)
        # Drop old column (SQLite needs batch mode, but we'll just leave it for now)
    elif "target_devices" not in task_columns:
        op.add_column("tasks", sa.Column("target_devices", sa.JSON(), nullable=True))

    # Submissions: add selected_device
    submission_columns = {col["name"] for col in inspector.get_columns("submissions")}
    if "selected_device" not in submission_columns:
        op.add_column("submissions", sa.Column("selected_device", sa.String(50), nullable=True))


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)

    submission_columns = {col["name"] for col in inspector.get_columns("submissions")}
    if "selected_device" in submission_columns:
        op.drop_column("submissions", "selected_device")

    task_columns = {col["name"] for col in inspector.get_columns("tasks")}
    if "target_devices" in task_columns:
        op.drop_column("tasks", "target_devices")

    user_columns = {col["name"] for col in inspector.get_columns("users")}
    if "allowed_devices" in user_columns:
        op.drop_column("users", "allowed_devices")
