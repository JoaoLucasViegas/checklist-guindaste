# app/routers/checklists.py
#
# PUT /api/v1/checklists/{checklist_id}
#
# O id é um UUID gerado pelo APP, então a mesma rota cria e edita
# (reenviar a mesma requisição não duplica nada).

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.erros import ErroNegocio
from app.models import Checklist, Equipamento, Evento, Local, Resposta, Revisao, Template
from app.schemas import ChecklistIn
from app.security import usuario_atual
from app.services.eventos import CAMPOS, calcular_diff
from app.services.impedimento import calcular_impedimento
from app.services.validacao import validar_checklist

router = APIRouter()

# Campos de controle: não entram no diff, mas são gravados e vão para o snapshot
CAMPOS_EXTRAS = ["usou_lote", "itens_marcados_lote", "itens_alterados_apos_lote",
                 "inicio_preenchimento_em", "finalizado_em", "duracao_segundos", "assinatura_operador"]


def itens_do_template(db: Session, template_id: str) -> list[dict]:
    t = db.get(Template, template_id)
    if not t:
        raise ErroNegocio(400, "VALIDACAO", "template_id inexistente")
    return [{"numero": i.numero, "critico": i.critico, "permite_na": i.permite_na} for i in t.itens]


def _conferir_referencias(db: Session, checklist_id: str, dados: dict) -> list[dict]:
    """Confere o que depende do banco: id é UUID; equipamento e local existem e estão ativos."""
    erros = []
    try:
        uuid.UUID(checklist_id)
    except ValueError:
        erros.append({"campo": "id", "mensagem": "Id do checklist deve ser um UUID válido."})
    eq = db.get(Equipamento, dados["equipamento_id"])
    if not eq or not eq.ativo:
        erros.append({"campo": "equipamento_id", "mensagem": "Equipamento não encontrado ou inativo."})
    loc = db.get(Local, dados["local_id"])
    if not loc or not loc.ativo:
        erros.append({"campo": "local_id", "mensagem": "Local não encontrado ou inativo."})
    return erros


def checklist_para_dict(c: Checklist) -> dict:
    """Mesma forma do corpo do PUT: serve para o diff e para o snapshot."""
    d = {campo: getattr(c, campo) for campo in CAMPOS + CAMPOS_EXTRAS}
    d["respostas"] = [{"item_numero": r.item_numero, "resposta": r.resposta, "origem": r.origem,
                       "observacao": r.observacao} for r in c.respostas]
    return d


@router.put("/checklists/{checklist_id}")
def salvar_checklist(checklist_id: str, body: ChecklistIn,
                     db: Session = Depends(get_db), usuario=Depends(usuario_atual)):
    # 1. Só OPERADOR envia
    if usuario.papel != "OPERADOR":
        raise ErroNegocio(403, "PERMISSAO", "Somente o operador envia checklists")

    # 2. Validação (400 se houver erros)
    dados = body.model_dump()
    itens = itens_do_template(db, dados["template_id"])
    erros = _conferir_referencias(db, checklist_id, dados) + validar_checklist(dados, itens)
    if erros:
        raise ErroNegocio(400, "VALIDACAO", "Checklist inválido", erros)

    # 3. Impedido
    impedido = calcular_impedimento(dados["respostas"], itens)["impedido"]

    # 4. Já existe?
    c = db.get(Checklist, checklist_id)
    if c is None:                                           # --- criação ---
        c = Checklist(id=checklist_id, operador_id=usuario.id, status="ENVIADO", revisao=1, editado=False)
        _aplicar(c, dados, impedido)
        db.add(c)
        db.add(Evento(checklist_id=checklist_id, tipo="CRIADO", usuario_id=usuario.id))
    else:                                                   # --- edição / reenvio ---
        if c.operador_id != usuario.id:                     # (a)
            raise ErroNegocio(403, "PERMISSAO", "Este checklist é de outro operador")
        if c.status == "VISTADO":                           # (b)
            raise ErroNegocio(409, "TRAVADO", "Checklist já vistado: não pode ser alterado")
        antigo = checklist_para_dict(c)
        diff = calcular_diff(antigo, dados)
        if not diff:                                        # (c) reenvio idêntico
            if c.status == "CORRECAO_SOLICITADA" and dados["confirmacao_correcao"]:
                # o operador conferiu e manteve tudo: sai de "correção solicitada" sem nova revisão
                c.status = "ENVIADO"
                db.add(Evento(checklist_id=c.id, tipo="REENVIADO", usuario_id=usuario.id,
                              detalhe={"diff": [], "confirmacao_correcao": True}))
                db.commit()
            return _resumo(c)
        # (d) houve mudança: guarda a versão antiga e aplica a nova
        db.add(Revisao(checklist_id=c.id, revisao=c.revisao, snapshot=antigo))
        tipo = "REENVIADO" if c.status == "CORRECAO_SOLICITADA" else "EDITADO"
        db.add(Evento(checklist_id=c.id, tipo=tipo, usuario_id=usuario.id,
                      detalhe={"diff": diff, "confirmacao_correcao": dados["confirmacao_correcao"]}))
        c.revisao += 1
        c.editado = True
        c.status = "ENVIADO"
        _aplicar(c, dados, impedido)

    # 5. Commit e resposta
    db.commit()
    return _resumo(c)


def _aplicar(c: Checklist, dados: dict, impedido: bool) -> None:
    """Copia os dados recebidos para o checklist e recria as respostas."""
    for campo in CAMPOS + CAMPOS_EXTRAS + ["criado_no_dispositivo_em", "app_versao"]:
        setattr(c, campo, dados.get(campo))
    c.impedido = impedido
    c.respostas.clear()                                     # delete-orphan apaga as antigas
    for r in dados["respostas"]:
        c.respostas.append(Resposta(item_numero=r["item_numero"], resposta=r["resposta"],
                                    origem=r.get("origem", "MANUAL"), observacao=r.get("observacao")))


def _resumo(c: Checklist) -> dict:
    return {"id": c.id, "status": c.status, "revisao": c.revisao, "impedido": c.impedido, "editado": c.editado}