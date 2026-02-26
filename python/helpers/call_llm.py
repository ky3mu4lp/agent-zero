from typing import Callable, TypedDict
from langchain.prompts import (
    ChatPromptTemplate,
    FewShotChatMessagePromptTemplate,
)

from langchain.schema import AIMessage
from langchain_core.messages import HumanMessage, SystemMessage

from langchain_core.language_models.chat_models import BaseChatModel
from langchain_core.language_models.llms import BaseLLM
from langchain_community.chat_models import ChatLiteLLM
import logging

logger = logging.getLogger(__name__)

# ── Free-Only Fallback Chain ───────────────────────────────────────────────────
# SECURITY RULE: Only free models listed here.
# Tasks/agents NEVER auto-switch to paid models without user confirmation.
# Order = priority: first is tried before the next.
FREE_FALLBACK_MODELS = [
    "openrouter/mistralai/mistral-7b-instruct:free",
    "openrouter/meta-llama/llama-3.1-8b-instruct:free",
]


class Example(TypedDict):
    input: str
    output: str


def _build_fallback_model(model_name: str) -> ChatLiteLLM | None:
    """Build a ChatLiteLLM fallback instance using the same OpenRouter API key."""
    try:
        import models as _models
        api_key = _models.get_api_key("openrouter")
        return ChatLiteLLM(
            model=model_name,
            api_key=api_key,
        )
    except Exception as e:
        logger.warning(f"call_llm: could not build fallback model {model_name}: {e}")
        return None


async def call_llm(
    system: str,
    model: BaseChatModel | BaseLLM,
    message: str,
    examples: list[Example] = [],
    callback: Callable[[str], None] | None = None
):

    example_prompt = ChatPromptTemplate.from_messages(
        [
            HumanMessage(content="{input}"),
            AIMessage(content="{output}"),
        ]
    )

    few_shot_prompt = FewShotChatMessagePromptTemplate(
        example_prompt=example_prompt,
        examples=examples,  # type: ignore
        input_variables=[],
    )

    few_shot_prompt.format()

    final_prompt = ChatPromptTemplate.from_messages(
        [
            SystemMessage(content=system),
            few_shot_prompt,
            HumanMessage(content=message),
        ]
    )

    # Build candidate list: primary model + free fallbacks
    candidates: list[BaseChatModel | BaseLLM] = [model]
    for name in FREE_FALLBACK_MODELS:
        fb = _build_fallback_model(name)
        if fb:
            candidates.append(fb)

    last_error: Exception | None = None

    for idx, current_model in enumerate(candidates):
        if idx > 0:
            model_label = getattr(current_model, "model", f"fallback-{idx}")
            logger.warning(
                f"call_llm: rate limit hit — switching to free fallback {idx}/{len(candidates)-1}: {model_label}"
            )

        try:
            chain = final_prompt | current_model

            response = ""
            async for chunk in chain.astream({}):
                if isinstance(chunk, str):
                    content = chunk
                elif hasattr(chunk, "content"):
                    content = str(chunk.content)
                else:
                    content = str(chunk)

                if callback:
                    callback(content)

                response += content

            return response

        except Exception as e:
            err_str = str(e).lower()
            is_rate_limit = "rate" in err_str and "limit" in err_str or "429" in err_str
            if is_rate_limit and idx < len(candidates) - 1:
                last_error = e
                continue  # try next free model
            raise  # non-rate-limit error OR all models exhausted

    if last_error:
        raise last_error
