"""add task templates and auto_approve

Revision ID: 0008_task_templates
Revises: 0007_achievements
Create Date: 2025-12-20
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0008_task_templates"
down_revision = "0007_achievements"
branch_labels = None
depends_on = None


# Default task templates
TEMPLATES = [
    {"title": "Hausaufgaben", "description": "Alle Hausaufgaben erledigen", "category": "schule",
     "duration_minutes": 60, "tan_reward": 20, "icon": "menu_book", "auto_approve": False},
    {"title": "Zimmer aufräumen", "description": "Zimmer ordentlich aufräumen", "category": "haushalt",
     "duration_minutes": 30, "tan_reward": 15, "icon": "bedroom_child", "auto_approve": False},
    {"title": "Zähne putzen", "description": "Morgens und abends Zähne putzen", "category": "hygiene",
     "duration_minutes": 5, "tan_reward": 5, "icon": "emoji_emotions", "auto_approve": True},
    {"title": "Bett machen", "description": "Bett ordentlich machen", "category": "haushalt",
     "duration_minutes": 5, "tan_reward": 5, "icon": "bed", "auto_approve": True},
    {"title": "Müll rausbringen", "description": "Müll zur Tonne bringen", "category": "haushalt",
     "duration_minutes": 10, "tan_reward": 10, "icon": "delete", "auto_approve": False},
    {"title": "Tisch decken", "description": "Tisch für das Essen decken", "category": "haushalt",
     "duration_minutes": 10, "tan_reward": 5, "icon": "restaurant", "auto_approve": True},
    {"title": "Spülmaschine ausräumen", "description": "Spülmaschine ausräumen und einräumen", "category": "haushalt",
     "duration_minutes": 15, "tan_reward": 10, "icon": "countertops", "auto_approve": False},
    {"title": "Haustier füttern", "description": "Haustier füttern und Wasser geben", "category": "haushalt",
     "duration_minutes": 10, "tan_reward": 10, "icon": "pets", "auto_approve": True},
    {"title": "Lesen üben", "description": "15 Minuten lesen üben", "category": "schule",
     "duration_minutes": 15, "tan_reward": 10, "icon": "auto_stories", "auto_approve": True},
    {"title": "Instrument üben", "description": "Musikinstrument üben", "category": "hobby",
     "duration_minutes": 30, "tan_reward": 15, "icon": "music_note", "auto_approve": False},
    {"title": "Sport/Bewegung", "description": "30 Minuten Sport oder Bewegung", "category": "gesundheit",
     "duration_minutes": 30, "tan_reward": 15, "icon": "fitness_center", "auto_approve": True},
    {"title": "Wäsche wegräumen", "description": "Saubere Wäsche in den Schrank räumen", "category": "haushalt",
     "duration_minutes": 15, "tan_reward": 10, "icon": "checkroom", "auto_approve": False},
]


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    existing_tables = inspector.get_table_names()

    # Add auto_approve column to tasks
    columns = [c['name'] for c in inspector.get_columns('tasks')]
    if 'auto_approve' not in columns:
        op.add_column('tasks', sa.Column('auto_approve', sa.Boolean(), server_default='0', nullable=False))

    # Create task_templates table
    if "task_templates" not in existing_tables:
        op.create_table(
            "task_templates",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("title", sa.String(200), nullable=False),
            sa.Column("description", sa.Text(), nullable=True),
            sa.Column("category", sa.String(50), nullable=True),
            sa.Column("duration_minutes", sa.Integer(), nullable=False, server_default="30"),
            sa.Column("tan_reward", sa.Integer(), nullable=False, server_default="30"),
            sa.Column("target_devices", sa.JSON(), nullable=True),
            sa.Column("requires_photo", sa.Boolean(), server_default="0"),
            sa.Column("auto_approve", sa.Boolean(), server_default="0"),
            sa.Column("icon", sa.String(50), nullable=True),
            sa.Column("is_system", sa.Boolean(), server_default="1"),
            sa.Column("sort_order", sa.Integer(), server_default="0"),
        )

        # Seed default templates
        for i, t in enumerate(TEMPLATES):
            op.execute(
                f"""INSERT INTO task_templates
                    (title, description, category, duration_minutes, tan_reward, icon, auto_approve, is_system, sort_order)
                    VALUES ('{t["title"]}', '{t["description"]}', '{t["category"]}',
                            {t["duration_minutes"]}, {t["tan_reward"]}, '{t["icon"]}',
                            {1 if t["auto_approve"] else 0}, 1, {i})"""
            )


def downgrade() -> None:
    op.drop_column('tasks', 'auto_approve')
    op.drop_table("task_templates")
