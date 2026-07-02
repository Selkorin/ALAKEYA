"""Pydantic models for browser-use service API requests and responses"""
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime


class AutomateRequest(BaseModel):
    task: str = Field(..., description="Natural language task to automate")
    session_id: Optional[str] = Field(None, description="Optional session ID for persistence")
    options: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Automation options")

    class Config:
        json_schema_extra = {
            "example": {
                "task": "Navigate to amazon.com and search for 'MacBook Pro'",
                "session_id": "optional-session-id",
                "options": {
                    "max_steps": 50,
                    "screenshot_every_step": True,
                    "wait_for_timeout": 30000
                }
            }
        }


class ExtractRequest(BaseModel):
    url: str = Field(..., description="URL to extract data from")
    extraction_goal: str = Field(default="extract", description="Goal: contacts, products, article, etc.")
    session_id: Optional[str] = Field(None, description="Optional session ID")
    options: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Extraction options")

    class Config:
        json_schema_extra = {
            "example": {
                "url": "https://example.com",
                "extraction_goal": "contacts",
                "session_id": "optional-session-id",
                "options": {
                    "include_screenshots": True,
                    "wait_for_dynamic_content": True
                }
            }
        }


class ScreenshotRequest(BaseModel):
    url: str = Field(..., description="URL to screenshot")
    session_id: Optional[str] = Field(None, description="Optional session ID")
    options: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Screenshot options")

    class Config:
        json_schema_extra = {
            "example": {
                "url": "https://example.com",
                "session_id": "optional-session-id",
                "options": {
                    "full_page": False,
                    "wait_for_render": 2000
                }
            }
        }


class SearchRequest(BaseModel):
    query: str = Field(..., description="Search query")
    max_results: int = Field(default=5, ge=1, le=20, description="Maximum number of results")
    extraction_goal: str = Field(default="summary", description="Extraction goal for results")
    options: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Search options")

    class Config:
        json_schema_extra = {
            "example": {
                "query": "MacBook Pro M3 reviews",
                "max_results": 5,
                "extraction_goal": "reviews_summary",
                "options": {
                    "include_screenshots": False
                }
            }
        }


class SessionCreateRequest(BaseModel):
    options: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Session options")

    class Config:
        json_schema_extra = {
            "example": {
                "options": {
                    "headless": True,
                    "user_agent": "custom",
                    "viewport": {"width": 1920, "height": 1080}
                }
            }
        }


class SuccessResponse(BaseModel):
    ok: bool = Field(True, description="Success status")
    data: Dict[str, Any] = Field(default_factory=dict, description="Response data")


class ErrorResponse(BaseModel):
    ok: bool = Field(False, description="Error status")
    error: str = Field(..., description="Error message")


class SessionInfo(BaseModel):
    session_id: str
    created_at: datetime
    last_activity: datetime
    is_active: bool


class HealthResponse(BaseModel):
    status: str
    browser_use_available: bool
    version: Optional[str] = None
