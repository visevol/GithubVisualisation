"""create repositories table

Revision ID: 7f0c4f26bfd0
Revises:
Create Date: 2024-09-28 17:24:13.233465

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7f0c4f26bfd0'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'repositories',
        sa.Column('id', sa.Integer, primary_key=True, autoincrement=True),
        sa.Column('remote_url', sa.String(255), nullable=False, index=True, unique=True),
    )

def downgrade() -> None:
    op.drop_table('repositories')
