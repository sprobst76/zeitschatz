"""Add login_code field for simple child authentication.

Revision ID: 0010_login_code
Revises: 0009_multi_family
Create Date: 2025-12-24
"""

from alembic import op
import sqlalchemy as sa

revision = '0010_login_code'
down_revision = '0009_multi_family'
branch_labels = None
depends_on = None


def upgrade():
    # Add login_code column to users table
    op.add_column('users', sa.Column('login_code', sa.String(30), nullable=True))

    # Create unique index for login_code
    op.create_index('ix_users_login_code', 'users', ['login_code'], unique=True)


def downgrade():
    op.drop_index('ix_users_login_code', table_name='users')
    op.drop_column('users', 'login_code')
