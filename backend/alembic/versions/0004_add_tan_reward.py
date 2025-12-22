"""add tan_reward column to tasks

Revision ID: 0004_add_tan_reward
Revises: 0003_add_tan_pool
Create Date: 2025-12-20
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0004_add_tan_reward"
down_revision = "0003_add_tan_pool"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    columns = {col["name"] for col in inspector.get_columns("tasks")}

    if "tan_reward" not in columns:
        op.add_column("tasks", sa.Column("tan_reward", sa.Integer(), nullable=True))
        # Set default value based on duration_minutes
        op.execute("UPDATE tasks SET tan_reward = duration_minutes WHERE tan_reward IS NULL")


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    columns = {col["name"] for col in inspector.get_columns("tasks")}

    if "tan_reward" in columns:
        op.drop_column("tasks", "tan_reward")
