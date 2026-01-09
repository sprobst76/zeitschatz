"""Add last_login field for tracking user activity.

Revision ID: 0011_last_login
Revises: 0010_login_code
Create Date: 2025-12-26
"""

from alembic import op
import sqlalchemy as sa

revision = '0011_last_login'
down_revision = '0010_login_code'
branch_labels = None
depends_on = None


def upgrade():
    # Add last_login column to users table
    op.add_column('users', sa.Column('last_login', sa.DateTime(), nullable=True))


def downgrade():
    op.drop_column('users', 'last_login')
