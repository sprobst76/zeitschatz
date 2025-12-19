"""initial tables

Revision ID: 0001_initial
Revises: 
Create Date: 2024-04-02
"""

from alembic import op
import sqlalchemy as sa


revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False),
        sa.Column("pin_hash", sa.String(length=255), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
    )
    op.create_index("ix_users_id", "users", ["id"], unique=False)

    op.create_table(
        "children_profiles",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("color", sa.String(length=20), nullable=True),
        sa.Column("icon", sa.String(length=50), nullable=True),
    )
    op.create_index("ix_children_profiles_id", "children_profiles", ["id"], unique=False)

    op.create_table(
        "tasks",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("category", sa.String(length=50), nullable=True),
        sa.Column("duration_minutes", sa.Integer(), nullable=False, server_default="30"),
        sa.Column("target_device", sa.String(length=50), nullable=True),
        sa.Column("requires_photo", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("recurrence", sa.JSON(), nullable=True),
        sa.Column("assigned_children", sa.JSON(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
    )
    op.create_index("ix_tasks_id", "tasks", ["id"], unique=False)
    op.create_index("ix_tasks_is_active", "tasks", ["is_active"], unique=False)

    op.create_table(
        "submissions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("task_id", sa.Integer(), sa.ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False),
        sa.Column("child_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="pending"),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("photo_path", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
    )
    op.create_index("ix_submissions_id", "submissions", ["id"], unique=False)
    op.create_index("ix_submissions_status_created", "submissions", ["status", "created_at"], unique=False)

    op.create_table(
        "tan_ledger",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("child_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("submission_id", sa.Integer(), sa.ForeignKey("submissions.id", ondelete="SET NULL"), nullable=True),
        sa.Column("minutes", sa.Integer(), nullable=False),
        sa.Column("target_device", sa.String(length=50), nullable=True),
        sa.Column("tan_code", sa.String(length=12), nullable=True),
        sa.Column("valid_until", sa.DateTime(), nullable=True),
        sa.Column("reason", sa.String(length=255), nullable=True),
        sa.Column("paid_out", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
    )
    op.create_index("ix_tan_ledger_id", "tan_ledger", ["id"], unique=False)
    op.create_index("ix_tan_ledger_child_paid", "tan_ledger", ["child_id", "paid_out"], unique=False)
    op.create_index("ux_tan_ledger_tan_code", "tan_ledger", ["tan_code"], unique=True)

    op.create_table(
        "device_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("fcm_token", sa.String(length=512), nullable=False),
        sa.Column("platform", sa.String(length=30), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
    )
    op.create_index("ix_device_tokens_id", "device_tokens", ["id"], unique=False)
    op.create_index("ux_device_tokens_fcm", "device_tokens", ["fcm_token"], unique=True)


def downgrade() -> None:
    op.drop_index("ux_device_tokens_fcm", table_name="device_tokens")
    op.drop_index("ix_device_tokens_id", table_name="device_tokens")
    op.drop_table("device_tokens")

    op.drop_index("ix_tan_ledger_child_paid", table_name="tan_ledger")
    op.drop_index("ux_tan_ledger_tan_code", table_name="tan_ledger")
    op.drop_index("ix_tan_ledger_id", table_name="tan_ledger")
    op.drop_table("tan_ledger")

    op.drop_index("ix_submissions_status_created", table_name="submissions")
    op.drop_index("ix_submissions_id", table_name="submissions")
    op.drop_table("submissions")

    op.drop_index("ix_tasks_is_active", table_name="tasks")
    op.drop_index("ix_tasks_id", table_name="tasks")
    op.drop_table("tasks")

    op.drop_index("ix_children_profiles_id", table_name="children_profiles")
    op.drop_table("children_profiles")

    op.drop_index("ix_users_id", table_name="users")
    op.drop_table("users")
