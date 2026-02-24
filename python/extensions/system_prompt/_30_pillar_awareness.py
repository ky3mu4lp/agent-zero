"""
_30_pillar_awareness.py
System prompt extension: injects the global pillar map when no project is active.
This ensures the agent always knows the 4 pillars even without an active project.
"""
from typing import Any
from python.helpers.extension import Extension
from python.helpers import projects, files
from agent import LoopData


PILLAR_MAP_PATH = "usr/knowledge/main/pillars.md"


class PillarAwareness(Extension):

    async def execute(
        self,
        system_prompt: list[str] = [],
        loop_data: LoopData = LoopData(),
        **kwargs: Any
    ):
        # Only inject pillar map when no project is active
        # (when a project IS active, it already injects full context via _10_system_prompt.py)
        project_name = self.agent.context.get_data(projects.CONTEXT_DATA_KEY_PROJECT)
        if not project_name:
            pillar_map = _load_pillar_map()
            if pillar_map:
                system_prompt.append(pillar_map)


def _load_pillar_map() -> str:
    try:
        path = files.get_abs_path(PILLAR_MAP_PATH)
        content = files.read_file(path)
        return content.strip() if content else ""
    except Exception:
        return ""
