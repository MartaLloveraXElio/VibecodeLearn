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


def _ejecutar(consulta):
    """Ejecuta una consulta a Supabase y convierte cualquier fallo (RLS,
    red, lo que sea) en un HTTPException normal.

    Si se deja que la excepción de Supabase se propague tal cual, FastAPI
    responde con un error 500 que se salta la capa de CORSMiddleware, así
    que el navegador lo ve como "bloqueado por CORS" en vez de mostrar el
    error real. Pasándolo por HTTPException, la respuesta sí lleva las
    cabeceras CORS y el error real llega hasta la app.
    """
    try:
        return consulta.execute()
    except Exception as error:
        raise HTTPException(status_code=502, detail=str(error)) from error


@app.get("/plazas")
def listar_plazas():
    respuesta = _ejecutar(supabase.table("plazas").select("*").order("id"))
    return respuesta.data


@app.put("/plazas/{plaza_id}/ocupar")
def ocupar_plaza(plaza_id: int, body: OcuparBody):
    respuesta = _ejecutar(
        supabase.table("plazas")
        .update({"ocupada": True, "ocupado_por": body.nombre})
        .eq("id", plaza_id)
    )
    if not respuesta.data:
        raise HTTPException(status_code=404, detail="Plaza no encontrada")
    return respuesta.data[0]


@app.put("/plazas/{plaza_id}/liberar")
def liberar_plaza(plaza_id: int):
    respuesta = _ejecutar(
        supabase.table("plazas")
        .update({"ocupada": False, "ocupado_por": None})
        .eq("id", plaza_id)
    )
    if not respuesta.data:
        raise HTTPException(status_code=404, detail="Plaza no encontrada")
    return respuesta.data[0]


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
