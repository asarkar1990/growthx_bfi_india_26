from __future__ import annotations
from datetime import date as Date
from enum import Enum
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

Day = Annotated[int, Field(ge=1, le=7)]

class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

class Confidence(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"

class ItemStatus(str, Enum):
    confirmed = "confirmed_from_source"
    needs_confirmation = "needs_confirmation"
    conflict = "conflict"

class Evidence(StrictModel):
    sourceEvidence: str = Field(min_length=1)
    page: int | None = Field(default=None, ge=1)
    confidence: Confidence
    status: ItemStatus
    uncertaintyReason: str | None = None

    @model_validator(mode="after")
    def uncertainty_is_explained(self):
        if self.status != ItemStatus.confirmed and not self.uncertaintyReason:
            raise ValueError("unconfirmed evidence requires an uncertainty reason")
        return self

class Medication(Evidence):
    id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    dose: str | None = None
    route: str | None = None
    frequency: str | None = None
    timing: list[Literal["morning", "afternoon", "evening", "bedtime", "anytime"]]
    duration: str | None = None
    specialInstructions: str | None = None
    simplifiedInstruction: str = Field(min_length=1)
    applicableDays: list[Day]

class CareInstruction(Evidence):
    id: str = Field(min_length=1)
    category: Literal["diet", "activity", "wound_care", "equipment", "other"]
    instruction: str = Field(min_length=1)
    simplifiedInstruction: str = Field(min_length=1)
    timing: Literal["morning", "afternoon", "evening", "bedtime", "anytime"]
    applicableDays: list[Day]

class FollowUp(Evidence):
    id: str = Field(min_length=1)
    type: Literal["appointment", "test", "procedure", "other"]
    title: str = Field(min_length=1)
    date: Date | None = None
    relativeTiming: str | None = None
    locationOrDepartment: str | None = None
    preparation: str | None = None

class WarningSign(Evidence):
    id: str = Field(min_length=1)
    sign: str = Field(min_length=1)
    action: str | None = None

class ConfirmationIssue(StrictModel):
    id: str = Field(min_length=1)
    severity: Literal["important", "advisory"]
    title: str = Field(min_length=1)
    questionForCareTeam: str = Field(min_length=1)
    sourceEvidence: str | None = None

class Patient(StrictModel):
    displayName: str | None = None
    dischargeDate: Date | None = None
    hospital: str | None = None
    department: str | None = None
    primaryConditionAsWritten: str | None = None

class DischargePlan(StrictModel):
    schemaVersion: Literal["1.0"] = "1.0"
    documentType: Literal["discharge_summary", "unsupported", "uncertain"]
    outputLanguage: Literal["en", "bn", "hi"]
    patient: Patient
    overview: str = Field(min_length=1)
    medications: list[Medication]
    careInstructions: list[CareInstruction]
    followUps: list[FollowUp]
    warningSigns: list[WarningSign]
    confirmationIssues: list[ConfirmationIssue]
    extractionWarnings: list[str]
