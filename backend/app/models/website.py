from sqlalchemy import Integer, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class CarouselImage(Base):
    __tablename__ = "website_carousel_images"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    url: Mapped[str] = mapped_column(Text, nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
