import logging
from collections.abc import Iterable

from redis import Redis
from redis.exceptions import RedisError

logger = logging.getLogger(__name__)


def cache_get(client: Redis | None, key: str) -> str | None:
    if client is None:
        return None
    try:
        value = client.get(key)
        return value if isinstance(value, str) else None
    except RedisError:
        logger.warning("cache_read_failed", extra={"cache_key": key})
        return None


def cache_set(client: Redis | None, key: str, value: str, ttl_seconds: int) -> None:
    if client is None:
        return
    try:
        client.set(key, value, ex=ttl_seconds)
    except RedisError:
        logger.warning("cache_write_failed", extra={"cache_key": key})


def invalidate_task_cache(client: Redis | None, task_id: str | None = None) -> None:
    if client is None:
        return
    try:
        keys: Iterable[str] = client.scan_iter(match="tasks:list:*")
        to_delete = list(keys)
        if task_id:
            to_delete.append(f"tasks:item:{task_id}")
        if to_delete:
            client.delete(*to_delete)
    except RedisError:
        logger.warning("cache_invalidation_failed")
