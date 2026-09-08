from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from datetime import datetime

from database import engine, get_db, Base
from models import TeacherDB, StudentDB, QuizDB, SessionDB, SubmissionDB, AnswerDB
from schemas import SessionSyncRequest, SyncResponse

# Automatically create all tables on startup
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="ClassSync Cloud Sync Service",
    description="Offline-First Classroom Assessment Sync Endpoint",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/health")
def health_check():
    return {
        "status": "online",
        "service": "ClassSync Cloud API",
        "timestamp": datetime.utcnow().isoformat(),
    }

@app.post("/api/sync/session", response_model=SyncResponse, status_code=status.HTTP_200_OK)
def sync_session_batch(payload: SessionSyncRequest, db: Session = Depends(get_db)):
    """
    Accepts a synchronized assessment session batch from a Teacher node,
    upserting teacher, quiz, session, submissions, and individual answers.
    """
    # 1. Ensure Teacher exists
    teacher = db.query(TeacherDB).filter(TeacherDB.teacher_id == payload.teacher_id).first()
    if not teacher:
        teacher = TeacherDB(
            teacher_id=payload.teacher_id,
            name=payload.teacher_name or "Prof. Anderson",
            public_key="cloud_registered_pubkey",
        )
        db.add(teacher)
        db.commit()

    # 2. Ensure Quiz exists
    quiz = db.query(QuizDB).filter(QuizDB.quiz_id == payload.quiz_id).first()
    if not quiz:
        quiz = QuizDB(
            quiz_id=payload.quiz_id,
            teacher_id=payload.teacher_id,
            title=f"Assessment {payload.session_code or payload.session_id}",
            time_limit=15,
            created_at=payload.started_at,
        )
        db.add(quiz)
        db.commit()

    # 3. Upsert Session
    session_db = db.query(SessionDB).filter(SessionDB.session_id == payload.session_id).first()
    if not session_db:
        session_db = SessionDB(
            session_id=payload.session_id,
            quiz_id=payload.quiz_id,
            teacher_id=payload.teacher_id,
            session_code=payload.session_code,
            qr_token=payload.qr_token,
            started_at=payload.started_at,
            status=payload.status,
            synced_at=datetime.utcnow(),
        )
        db.add(session_db)
    else:
        session_db.status = payload.status
        session_db.synced_at = datetime.utcnow()
    db.commit()

    # 4. Upsert Submissions & Answers
    synced_count = 0
    for sub in payload.submissions:
        # Ensure student exists
        student = db.query(StudentDB).filter(StudentDB.student_id == sub.student_id).first()
        if not student:
            student = StudentDB(
                student_id=sub.student_id,
                name=sub.student_name or sub.student_id,
                public_key="cloud_synced_pubkey",
                class_id="DEFAULT_CLASS",
            )
            db.add(student)
            db.commit()

        # Upsert Submission
        sub_db = db.query(SubmissionDB).filter(SubmissionDB.submission_id == sub.submission_id).first()
        if not sub_db:
            sub_db = SubmissionDB(
                submission_id=sub.submission_id,
                session_id=sub.session_id,
                student_id=sub.student_id,
                device_id=sub.device_id,
                start_ts=sub.start_ts,
                submit_ts=sub.submit_ts,
                student_signature=sub.student_signature,
                sync_status="synced",
                score=sub.score,
                total_possible_marks=sub.total_possible_marks,
                status=sub.status,
                is_signature_verified=sub.is_signature_verified,
                is_hash_chain_verified=sub.is_hash_chain_verified,
            )
            db.add(sub_db)
        else:
            sub_db.score = sub.score
            sub_db.status = sub.status
            sub_db.sync_status = "synced"
            sub_db.is_signature_verified = sub.is_signature_verified
            sub_db.is_hash_chain_verified = sub.is_hash_chain_verified
        db.commit()

        # Upsert Answers if present
        if sub.answers:
            for q_id, ans in sub.answers.items():
                ans_id = ans.answer_id or f"ans_{sub.submission_id}_{q_id}"
                ans_db = db.query(AnswerDB).filter(AnswerDB.answer_id == ans_id).first()
                if not ans_db:
                    ans_db = AnswerDB(
                        answer_id=ans_id,
                        submission_id=sub.submission_id,
                        question_id=ans.question_id,
                        response=ans.response,
                        hash_chain_link=ans.hash_chain_link,
                    )
                    db.add(ans_db)
                else:
                    ans_db.response = ans.response
                    ans_db.hash_chain_link = ans.hash_chain_link
            db.commit()

        synced_count += 1

    return SyncResponse(
        status="success",
        message="Session and submissions successfully synchronized to cloud",
        session_id=payload.session_id,
        submissions_synced=synced_count,
        synced_at=datetime.utcnow(),
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
