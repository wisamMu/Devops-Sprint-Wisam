"""Sprint Items API - the DevOps sprint capstone app."""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Sprint Items API", version="0.1.0")


class Item(BaseModel):
    name: str
    price: float


ITEMS: dict[int, Item] = {
    1: Item(name="laptop stand", price=25.0),
    2: Item(name="usb-c cable", price=9.5),
}


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/items")
def list_items() -> list[dict]:
    return [{"id": item_id, **item.model_dump()} for item_id, item in ITEMS.items()]


@app.get("/items/{item_id}")
def get_item(item_id: int) -> dict:
    if item_id not in ITEMS:
        raise HTTPException(status_code=404, detail="Item not found")
    return {"id": item_id, **ITEMS[item_id].model_dump()}


@app.post("/items", status_code=201)
def create_item(item: Item) -> dict:
    item_id = max(ITEMS, default=0) + 1
    ITEMS[item_id] = item
    return {"id": item_id, **item.model_dump()}
