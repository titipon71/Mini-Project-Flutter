from pydantic import BaseModel


class WebsiteInfoOut(BaseModel):
    carouselImages: list[str]


class WebsiteInfoUpdate(BaseModel):
    carouselImages: list[str]
