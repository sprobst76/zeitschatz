"""add tan_pool table for TAN management

Revision ID: 0003_add_tan_pool
Revises: 0002_add_photo_expires_at
Create Date: 2025-12-20
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0003_add_tan_pool"
down_revision = "0002_add_photo_expires_at"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    tables = inspector.get_table_names()

    if "tan_pool" not in tables:
        op.create_table(
            "tan_pool",
            sa.Column("id", sa.Integer(), primary_key=True, index=True),
            sa.Column("tan_code", sa.String(12), unique=True, nullable=False, index=True),
            sa.Column("minutes", sa.Integer(), nullable=False),
            sa.Column("target_device", sa.String(50), nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("used", sa.Boolean(), default=False, nullable=False),
            sa.Column("used_at", sa.DateTime(), nullable=True),
            sa.Column("used_by_child_id", sa.Integer(), nullable=True),
        )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    tables = inspector.get_table_names()

    if "tan_pool" in tables:
        op.drop_table("tan_pool")
