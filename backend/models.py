from sqlalchemy import Column, String, Integer, DateTime, Boolean, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

class TeacherDB(Base):
    __tablename__ = "teachers"

    teacher_id = Column(String(64), primary_key=True, index=True)
    name = Column(String(128), nullable=False)
    public_key = Column(Text, nullable=False)
    private_key_hash = Column(String(128), nullable=True)

    quizzes = relationship("QuizDB", back_populates="teacher")
    sessions = relationship("SessionDB", back_populates="teacher")

class StudentDB(Base):
    __tablename__ = "students"

    student_id = Column(String(64), primary_key=True, index=True)
    name = Column(String(128), nullable=False)
    public_key = Column(Text, nullable=False)
    class_id = Column(String(64), nullable=False)

    submissions = relationship("SubmissionDB", back_populates="student")

class QuizDB(Base):
    __tablename__ = "quizzes"

    quiz_id = Column(String(64), primary_key=True, index=True)
    teacher_id = Column(String(64), ForeignKey("teachers.teacher_id"), nullable=False)
    title = Column(String(256), nullable=False)
    description = Column(Text, nullable=True)
    time_limit = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    signature = Column(Text, nullable=True)

    teacher = relationship("TeacherDB", back_populates="quizzes")
    sessions = relationship("SessionDB", back_populates="quiz")

class SessionDB(Base):
    __tablename__ = "sessions"

    session_id = Column(String(64), primary_key=True, index=True)
    quiz_id = Column(String(64), ForeignKey("quizzes.quiz_id"), nullable=False)
    teacher_id = Column(String(64), ForeignKey("teachers.teacher_id"), nullable=False)
    session_code = Column(String(32), nullable=True)
    qr_token = Column(String(128), nullable=False)
    started_at = Column(DateTime, default=datetime.utcnow)
    status = Column(String(32), default="completed")
    synced_at = Column(DateTime, default=datetime.utcnow)

    quiz = relationship("QuizDB", back_populates="sessions")
    teacher = relationship("TeacherDB", back_populates="sessions")
    submissions = relationship("SubmissionDB", back_populates="session")

class SubmissionDB(Base):
    __tablename__ = "submissions"

    submission_id = Column(String(64), primary_key=True, index=True)
    session_id = Column(String(64), ForeignKey("sessions.session_id"), nullable=False)
    student_id = Column(String(64), ForeignKey("students.student_id"), nullable=False)
    device_id = Column(String(64), nullable=False)
    start_ts = Column(DateTime, nullable=False)
    submit_ts = Column(DateTime, nullable=False)
    student_signature = Column(Text, nullable=False)
    sync_status = Column(String(32), default="synced")
    score = Column(Integer, default=0)
    total_possible_marks = Column(Integer, default=0)
    status = Column(String(32), default="graded")
    is_signature_verified = Column(Boolean, default=True)
    is_hash_chain_verified = Column(Boolean, default=True)

    session = relationship("SessionDB", back_populates="submissions")
    student = relationship("StudentDB", back_populates="submissions")
    answers = relationship("AnswerDB", back_populates="submission")

class AnswerDB(Base):
    __tablename__ = "answers"

    answer_id = Column(String(64), primary_key=True, index=True)
    submission_id = Column(String(64), ForeignKey("submissions.submission_id"), nullable=False)
    question_id = Column(String(64), nullable=False)
    response = Column(String(256), nullable=False)
    hash_chain_link = Column(Text, nullable=False)

    submission = relationship("SubmissionDB", back_populates="answers")
