import os

import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from supabase import create_client, Client

load_dotenv()

supabase: Client = create_client(
    os.environ["SUPABASE_URL"],
    os.environ["SUPABASE_KEY"],
)

app = FastAPI(title="Garaje API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class OcuparBody(BaseModel):
    nombre: str


@app.get("/plazas")
def listar_plazas():
    respuesta = supabase.table("plazas").select("*").order("id").execute()
    return respuesta.data


@app.put("/plazas/{plaza_id}/ocupar")
def ocupar_plaza(plaza_id: int, body: OcuparBody):
    respuesta = (
        supabase.table("plazas")
        .update({"ocupada": True, "ocupado_por": body.nombre})
        .eq("id", plaza_id)
        .execute()
    )
    if not respuesta.data:
        raise HTTPException(status_code=404, detail="Plaza no encontrada")
    return respuesta.data[0]


@app.put("/plazas/{plaza_id}/liberar")
def liberar_plaza(plaza_id: int):
    respuesta = (
        supabase.table("plazas")
        .update({"ocupada": False, "ocupado_por": None})
        .eq("id", plaza_id)
        .execute()
    )
    if not respuesta.data:
        raise HTTPException(status_code=404, detail="Plaza no encontrada")
    return respuesta.data[0]


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
