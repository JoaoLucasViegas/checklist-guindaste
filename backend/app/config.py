
"""Configuração lida de variáveis de ambiente."""

import os


class Settings:

    # Configuração do banco de dados
    DATABASE_URL: str = os.getenv("DATABASE_URL","sqlite:///./checklist.db")

    # Configuração JWT
    JWT_SECRET: str = os.getenv("JWT_SECRET","troque-esta-chave-na-demo")

    JWT_EXPIRA_HORAS: int = int(os.getenv("JWT_EXPIRA_HORAS", "12"))

    # Configuração dos seeds
    SEED_DIR: str = os.getenv("SEED_DIR", "../dados/seed")

    # Configuração CORS
    CORS_ORIGENS: str = os.getenv( "CORS_ORIGENS", "*")


settings = Settings()
