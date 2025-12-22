"""add achievements tables

Revision ID: 0007_achievements
Revises: 0006_learning_tables
Create Date: 2025-12-20
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0007_achievements"
down_revision = "0006_learning_tables"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()

    if "achievements" not in existing_tables:
        op.create_table(
            "achievements",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("code", sa.String(50), unique=True, nullable=False),
            sa.Column("name", sa.String(100), nullable=False),
            sa.Column("description", sa.Text(), nullable=True),
            sa.Column("icon", sa.String(50), nullable=False, server_default="star"),
            sa.Column("category", sa.String(50), nullable=False, server_default="general"),
            sa.Column("threshold", sa.Integer(), nullable=True),
            sa.Column("reward_minutes", sa.Integer(), nullable=True),
            sa.Column("is_active", sa.Boolean(), server_default="1"),
            sa.Column("sort_order", sa.Integer(), server_default="0"),
        )
        op.create_index("ix_achievements_code", "achievements", ["code"])
        op.create_index("ix_achievements_category", "achievements", ["category"])

    if "user_achievements" not in existing_tables:
        op.create_table(
            "user_achievements",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("achievement_id", sa.Integer(), sa.ForeignKey("achievements.id", ondelete="CASCADE"), nullable=False),
            sa.Column("unlocked_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
            sa.Column("notified", sa.Boolean(), server_default="0"),
        )
        op.create_index("ix_user_achievements_user_id", "user_achievements", ["user_id"])
        op.create_index("ix_user_achievements_achievement_id", "user_achievements", ["achievement_id"])


def downgrade() -> None:
    op.drop_table("user_achievements")
    op.drop_table("achievements")
