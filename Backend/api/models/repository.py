from sqlalchemy import String
from sqlalchemy.orm import Mapped
from sqlalchemy.orm import mapped_column

from api.models.base import Base


class Repository(Base):
   __tablename__ = 'repositories'

   id: Mapped[int] = mapped_column(primary_key=True)
   remote_url: Mapped[str] = mapped_column(String(255))

   def __repr__(self) -> str:
       return f"Repository(id={self.id}, remote_url={self.remote_url})"
