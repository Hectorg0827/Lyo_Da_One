import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy import text, select
import os

DATABASE_URL = "postgresql+asyncpg://lyo_dev:lyo_secret_password@localhost:5432/lyo_db"
# Wait, let me try to use the SAME url the backend uses!
