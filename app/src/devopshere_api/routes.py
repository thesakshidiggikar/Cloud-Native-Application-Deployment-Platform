import json
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from devopshere_api.cache import cache_get, cache_set, invalidate_task_cache
from devopshere_api.database import get_session
from devopshere_api.models import Task
from devopshere_api.schemas import TaskCreate, TaskRead, TaskStatus, TaskUpdate

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/tasks", tags=["tasks"])


def _cache(request: Request):
    return request.app.state.cache


@router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
def create_task(
    payload: TaskCreate,
    request: Request,
    session: Session = Depends(get_session),
) -> Task:
    task = Task(
        title=payload.title,
        description=payload.description,
        status=payload.status.value,
    )
    session.add(task)
    session.commit()
    session.refresh(task)
    invalidate_task_cache(_cache(request))
    return task


@router.get("", response_model=list[TaskRead])
def list_tasks(
    request: Request,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    session: Session = Depends(get_session),
) -> list[TaskRead]:
    key = f"tasks:list:{limit}:{offset}"
    cached = cache_get(_cache(request), key)
    if cached:
        try:
            return [TaskRead.model_validate(item) for item in json.loads(cached)]
        except (ValueError, TypeError):
            logger.warning("cache_payload_invalid", extra={"cache_key": key})

    rows = session.scalars(
        select(Task).order_by(Task.created_at.desc(), Task.id).limit(limit).offset(offset)
    ).all()
    result = [TaskRead.model_validate(row) for row in rows]
    cache_set(
        _cache(request),
        key,
        json.dumps([item.model_dump(mode="json") for item in result]),
        request.app.state.settings.cache_ttl_seconds,
    )
    return result


@router.get("/{task_id}", response_model=TaskRead)
def get_task(
    task_id: str,
    request: Request,
    session: Session = Depends(get_session),
) -> TaskRead | Task:
    key = f"tasks:item:{task_id}"
    cached = cache_get(_cache(request), key)
    if cached:
        try:
            return TaskRead.model_validate_json(cached)
        except (ValueError, TypeError):
            logger.warning("cache_payload_invalid", extra={"cache_key": key})

    task = session.get(Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    cache_set(
        _cache(request),
        key,
        TaskRead.model_validate(task).model_dump_json(),
        request.app.state.settings.cache_ttl_seconds,
    )
    return task


@router.patch("/{task_id}", response_model=TaskRead)
def update_task(
    task_id: str,
    payload: TaskUpdate,
    request: Request,
    session: Session = Depends(get_session),
) -> Task:
    task = session.get(Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    changes = payload.model_dump(exclude_unset=True)
    if "status" in changes and changes["status"] is not None:
        changes["status"] = TaskStatus(changes["status"]).value
    for field, value in changes.items():
        setattr(task, field, value)
    session.commit()
    session.refresh(task)
    invalidate_task_cache(_cache(request), task_id)
    return task


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(
    task_id: str,
    request: Request,
    session: Session = Depends(get_session),
) -> Response:
    task = session.get(Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    session.delete(task)
    session.commit()
    invalidate_task_cache(_cache(request), task_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
