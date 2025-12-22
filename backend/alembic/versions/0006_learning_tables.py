"""add learning tables

Revision ID: 0006_learning_tables
Revises: 0005_device_changes
Create Date: 2025-12-20
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0006_learning_tables"
down_revision = "0005_device_changes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()

    if "learning_sessions" not in existing_tables:
        op.create_table(
            "learning_sessions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("child_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("subject", sa.String(50), nullable=False),
            sa.Column("difficulty", sa.String(20), nullable=False),
            sa.Column("total_questions", sa.Integer(), default=10),
            sa.Column("correct_answers", sa.Integer(), default=0),
            sa.Column("wrong_answers", sa.Integer(), default=0),
            sa.Column("time_seconds", sa.Integer(), nullable=True),
            sa.Column("completed", sa.Boolean(), default=False),
            sa.Column("tan_reward", sa.Integer(), nullable=True),
            sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
            sa.Column("completed_at", sa.DateTime(), nullable=True),
        )
        op.create_index("ix_learning_sessions_child_id", "learning_sessions", ["child_id"])

    if "learning_progress" not in existing_tables:
        op.create_table(
            "learning_progress",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("child_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("subject", sa.String(50), nullable=False),
            sa.Column("difficulty", sa.String(20), nullable=False),
            sa.Column("total_attempted", sa.Integer(), default=0),
            sa.Column("total_correct", sa.Integer(), default=0),
            sa.Column("sessions_completed", sa.Integer(), default=0),
            sa.Column("last_session_at", sa.DateTime(), nullable=True),
        )
        op.create_index("ix_learning_progress_child_id", "learning_progress", ["child_id"])


def downgrade() -> None:
    op.drop_table("learning_progress")
    op.drop_table("learning_sessions")
