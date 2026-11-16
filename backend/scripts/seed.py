"""Popula o banco com usuários, locais, equipamentos e o template (BE-02).
Deve ser IDEMPOTENTE (rodar 2x não duplica).
Fontes: settings.SEED_DIR (dados/seed/*.json). PIN vira hash argon2; nunca salvar texto puro.
Uso (no container): python scripts/seed.py
"""
# TODO BE-02
