from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from datetime import datetime

class AnswerSyncSchema(BaseModel):
    answer_id: Optional[str] = None
    question_id: str
    response: str
    hash_chain_link: str

class SubmissionSyncSchema(BaseModel):
    submission_id: str
    session_id: str
    student_id: str
    student_name: Optional[str] = ""
    student_roll_number: Optional[str] = ""
    device_id: str
    start_ts: datetime
    submit_ts: datetime
    student_signature: str
    score: int = 0
    total_possible_marks: int = 0
    status: str = "graded"
    is_signature_verified: bool = True
    is_hash_chain_verified: bool = True
    answers: Optional[Dict[str, AnswerSyncSchema]] = None

class SessionSyncRequest(BaseModel):
    session_id: str
    quiz_id: str
    teacher_id: str
    teacher_name: Optional[str] = "Prof. Anderson"
    session_code: Optional[str] = None
    qr_token: str
    started_at: datetime
    status: str = "completed"
    submissions: List[SubmissionSyncSchema] = []

class SyncResponse(BaseModel):
    status: str
    message: str
    session_id: str
    submissions_synced: int
    synced_at: datetime
