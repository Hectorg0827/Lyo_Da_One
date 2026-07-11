import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy import text
from sqlalchemy.orm import sessionmaker

async def main():
    engine = create_async_engine("postgresql+asyncpg://postgres:postgres@localhost:5432/lyo", echo=True)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        try:
            # force an error
            await session.execute(text("SELECT * FROM non_existent_table"))
        except Exception as e:
            print("Caught exception:", e)
            await session.rollback()
            
        print("\n\n--- AFTER ROLLBACK ---\n")
        try:
            res = await session.execute(text("SELECT 1"))
            print("SUCCESS:", res.scalar())
        except Exception as e:
            print("FAILED AGAIN:", e)

asyncio.run(main())
