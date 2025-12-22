"""Multi-family support with provider-per-device

Revision ID: 0009_multi_family
Revises: 0008_task_templates
Create Date: 2025-12-22

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0009_multi_family'
down_revision = '0008_task_templates'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create families table
    op.create_table(
        'families',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('invite_code', sa.String(length=16), nullable=True),
        sa.Column('invite_expires_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='1'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_families_id', 'families', ['id'])
    op.create_index('ix_families_invite_code', 'families', ['invite_code'], unique=True)

    # Create family_members table
    op.create_table(
        'family_members',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('family_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('role_in_family', sa.String(length=20), nullable=False),
        sa.Column('joined_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['family_id'], ['families.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('family_id', 'user_id', name='uq_family_user')
    )
    op.create_index('ix_family_members_id', 'family_members', ['id'])
    op.create_index('ix_family_members_family', 'family_members', ['family_id'])
    op.create_index('ix_family_members_user', 'family_members', ['user_id'])

    # Create device_providers table (provider per device per family)
    op.create_table(
        'device_providers',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('family_id', sa.Integer(), nullable=False),
        sa.Column('device_type', sa.String(length=20), nullable=False),
        sa.Column('provider_type', sa.String(length=30), nullable=False),
        sa.Column('provider_settings', sa.JSON(), nullable=True),
        sa.ForeignKeyConstraint(['family_id'], ['families.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('family_id', 'device_type', name='uq_family_device')
    )
    op.create_index('ix_device_providers_id', 'device_providers', ['id'])
    op.create_index('ix_device_providers_family', 'device_providers', ['family_id'])

    # Create reward_providers registry table
    op.create_table(
        'reward_providers',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('code', sa.String(length=30), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('requires_tan_pool', sa.Boolean(), nullable=False, server_default='0'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='1'),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_reward_providers_id', 'reward_providers', ['id'])
    op.create_index('ix_reward_providers_code', 'reward_providers', ['code'], unique=True)

    # Seed default providers
    op.execute("""
        INSERT INTO reward_providers (code, name, description, requires_tan_pool, sort_order) VALUES
        ('kisi', 'Salfeld Kisi', 'TAN-basierte Belohnungen mit Kisi-Codes', 1, 1),
        ('family_link', 'Google Family Link', 'Manuelle Zeitfreigabe in Family Link', 0, 2),
        ('manual', 'Manuell', 'Manuelle Zeiterfassung ohne externes System', 0, 3)
    """)

    # Add email/password columns to users
    op.add_column('users', sa.Column('email', sa.String(length=255), nullable=True))
    op.add_column('users', sa.Column('password_hash', sa.String(length=255), nullable=True))
    op.add_column('users', sa.Column('email_verified', sa.Boolean(), nullable=False, server_default='0'))
    op.add_column('users', sa.Column('verification_token', sa.String(length=64), nullable=True))
    op.add_column('users', sa.Column('reset_token', sa.String(length=64), nullable=True))
    op.add_column('users', sa.Column('reset_expires_at', sa.DateTime(), nullable=True))
    op.create_index('ix_users_email', 'users', ['email'], unique=True)

    # Make pin_hash nullable (for email-only parents)
    # SQLite doesn't support ALTER COLUMN, so we skip this for SQLite
    # For PostgreSQL: op.alter_column('users', 'pin_hash', nullable=True)

    # Add family_id to tasks (SQLite-compatible: just add column, FK enforced at app level)
    op.add_column('tasks', sa.Column('family_id', sa.Integer(), nullable=True))
    op.create_index('ix_tasks_family', 'tasks', ['family_id'])

    # Add family_id to tan_pool
    op.add_column('tan_pool', sa.Column('family_id', sa.Integer(), nullable=True))
    op.create_index('ix_tan_pool_family', 'tan_pool', ['family_id'])

    # Add family_id to submissions
    op.add_column('submissions', sa.Column('family_id', sa.Integer(), nullable=True))
    op.create_index('ix_submissions_family', 'submissions', ['family_id'])

    # Add family_id and provider_type to tan_ledger
    op.add_column('tan_ledger', sa.Column('family_id', sa.Integer(), nullable=True))
    op.add_column('tan_ledger', sa.Column('provider_type', sa.String(length=30), nullable=True))
    op.create_index('ix_tan_ledger_family', 'tan_ledger', ['family_id'])


def downgrade() -> None:
    # Remove family_id from tan_ledger
    op.drop_index('ix_tan_ledger_family', 'tan_ledger')
    op.drop_column('tan_ledger', 'provider_type')
    op.drop_column('tan_ledger', 'family_id')

    # Remove family_id from submissions
    op.drop_index('ix_submissions_family', 'submissions')
    op.drop_column('submissions', 'family_id')

    # Remove family_id from tan_pool
    op.drop_index('ix_tan_pool_family', 'tan_pool')
    op.drop_column('tan_pool', 'family_id')

    # Remove family_id from tasks
    op.drop_index('ix_tasks_family', 'tasks')
    op.drop_column('tasks', 'family_id')

    # Remove email/password columns from users
    op.drop_index('ix_users_email', 'users')
    op.drop_column('users', 'reset_expires_at')
    op.drop_column('users', 'reset_token')
    op.drop_column('users', 'verification_token')
    op.drop_column('users', 'email_verified')
    op.drop_column('users', 'password_hash')
    op.drop_column('users', 'email')

    # Drop tables
    op.drop_table('reward_providers')
    op.drop_table('device_providers')
    op.drop_table('family_members')
    op.drop_table('families')
