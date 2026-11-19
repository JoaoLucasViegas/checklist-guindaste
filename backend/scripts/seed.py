# Pode rodar várias vezes: não duplica dados que já existem.
import json
import os
from pathlib import Path

from argon2 import PasswordHasher
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app import models as m
from app.db import Base

PASTA_DADOS = Path(__file__).parent / "dados"
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./app.db")

hasher = PasswordHasher()  # argon2


def ler_json(nome_arquivo: str) -> dict:
    caminho = PASTA_DADOS / nome_arquivo
    with open(caminho, encoding="utf-8") as f:
        return json.load(f)


def seed_usuarios(db: Session, lista: list[dict]) -> None:
    for u in lista:
        existe = db.scalar(select(m.Usuario).where(m.Usuario.matricula == u["matricula"]))
        if existe:
            continue
        db.add(
            m.Usuario(
                matricula=u["matricula"],
                nome=u["nome"],
                papel=u["papel"],
                pin_hash=hasher.hash(u["pin"]),  # nunca salvar o PIN puro
            )
        )


def seed_locais(db: Session, lista: list[dict]) -> None:
    for item in lista:
        existe = db.scalar(select(m.Local).where(m.Local.nome == item["nome"]))
        if not existe:
            db.add(m.Local(nome=item["nome"]))


def seed_equipamentos(db: Session, lista: list[dict]) -> None:
    for item in lista:
        existe = db.scalar(
            select(m.Equipamento).where(m.Equipamento.identificacao == item["identificacao"])
        )
        if not existe:
            db.add(m.Equipamento(identificacao=item["identificacao"]))


def seed_template(db: Session, dados: dict) -> None:
    existe = db.scalar(
        select(m.Template).where(
            m.Template.codigo == dados["codigo"],
            m.Template.versao == dados["versao"],
        )
    )
    if existe:
        return

    # Versões antigas do mesmo formulário deixam de ser a ativa
    antigos = db.scalars(select(m.Template).where(m.Template.codigo == dados["codigo"]))
    for antigo in antigos:
        antigo.ativo = False

    template = m.Template(
        codigo=dados["codigo"],
        versao=dados["versao"],
        data_versao=dados["data_versao"],
        titulo=dados["titulo"],
        ativo=True,
        itens=[
            m.TemplateItem(
                numero=i["numero"],
                descricao=i["descricao"],
                critico=i["critico"],
                permite_na=i["permite_na"],
            )
            for i in dados["itens"]
        ],
    )
    db.add(template)


def main() -> None:
    engine = create_engine(DATABASE_URL)
    Base.metadata.create_all(engine)  # cria as tabelas se ainda não existirem

    demo = ler_json("demo.json")
    template = ler_json("checklist_template.json")

    with Session(engine) as db:
        seed_usuarios(db, demo["usuarios"])
        seed_locais(db, demo["locais"])
        seed_equipamentos(db, demo["equipamentos"])
        seed_template(db, template)
        db.commit()

    print("Seed concluído.")


if __name__ == "__main__":
    main()