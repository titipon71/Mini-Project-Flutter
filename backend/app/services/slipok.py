import httpx
from app.config import settings


async def verify_slip_by_url(slip_url: str, amount: float, log: bool = True) -> dict:
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            settings.SLIPOK_ENDPOINT,
            headers={
                "Content-Type": "application/json",
                "x-authorization": settings.SLIPOK_API_KEY,
            },
            json={"url": slip_url, "amount": amount, "log": log},
        )
        resp.raise_for_status()
        return resp.json()
