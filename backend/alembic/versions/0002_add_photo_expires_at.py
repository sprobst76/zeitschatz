"""add photo_expires_at to submissions if missing

Revision ID: 0002_add_photo_expires_at
Revises: 0001_initial
Create Date: 2025-12-20
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0002_add_photo_expires_at"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    columns = {col["name"] for col in inspector.get_columns("submissions")}
    if "photo_expires_at" not in columns:
        op.add_column("submissions", sa.Column("photo_expires_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    columns = {col["name"] for col in inspector.get_columns("submissions")}
    if "photo_expires_at" in columns:
        op.drop_column("submissions", "photo_expires_at")
