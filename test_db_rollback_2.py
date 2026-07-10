import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy import text, select

DATABASE_URL = "postgresql+asyncpg://lyo_dev:lyo_secret_password@localhost:5432/lyo_db"
engine = create_async_engine(DATABASE_URL, echo=True)

async def main():
    async with AsyncSession(engine) as session:
        # A successful query
        await session.execute(text("SELECT 1"))
        
        try:
            # A query that fails
            await session.execute(text("SELECT * FROM non_existent_table_123"))
        except Exception as e:
            print("Caught exception:", e)
            # This is what personalization_engine does!
            await session.rollback()
            
        print("Now executing next query...")
        try:
            await session.execute(text("SELECT 2"))
            print("Next query SUCCESS!")
        except Exception as e:
            print("Next query FAILED:", e)

asyncio.run(main())
