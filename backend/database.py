import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# Uses DATABASE_URL from environment (e.g. postgresql://user:pass@localhost:5432/classsync)
# Defaults to a local sqlite file for seamless offline/standalone developer execution
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./classsync_cloud.db")

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
