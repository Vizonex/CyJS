from cyjs import PromiseHookType, Context, Runtime, Promise
from dataclasses import dataclass
import pytest


# Reflects test api-test.c
# void promise_hook(void) Line: 523 - 661
# which contains pretty easy code to replicate.
# we don't run the entire thing but we want to at least ensure the callbacks are indeed 1 to 1.


@dataclass
class Counter:
    init: int = 0
    before: int = 0
    after: int = 0
    resolve: int = 0

    def on_promise(
        self, ctx: Context, hook: PromiseHookType, promise: Promise, parent: object
    ):
        assert isinstance(promise, Promise), "promise was not actually a promise :("
        match hook:
            case PromiseHookType.INIT:
                self.init += 1
            case PromiseHookType.BEFORE:
                self.before += 1
            case PromiseHookType.AFTER:
                self.after += 1
            case PromiseHookType.RESOLVE:
                self.resolve += 1

    def is_equal_to(self, init: int, before: int, after: int, resolve: int) -> bool:
        return (
            self.init == init
            and self.before == before
            and self.after == after
            and self.resolve == resolve
        )


@dataclass
class Case:
    code: str
    expected: tuple[int, int, int, int]
    id: int

    def __str__(self) -> str:
        return str(self.id)


@pytest.fixture(scope="function")
def setup_ctx() -> tuple[Context, Counter]:
    rt = Runtime()
    ctx = Context(rt)
    counter = Counter()
    rt.set_promise_hook(counter.on_promise)
    return ctx, counter


@pytest.fixture(
    params=(
        Case("new Promise(() => {})", (3, 0, 0, 2), 1),
        Case("new Promise((resolve,reject) => resolve())", (3, 0, 0, 3), 2),
        Case("new Promise((resolve,reject) => reject())", (3, 0, 0, 2), 3),
        # Case("new Promise(resolve => resolve({then(resolve){ resolve() }}))", ()) TODO:...
    ),
    ids=str,
)
def promise_hook(request: pytest.FixtureRequest) -> Case:
    return request.param


def test_hooks(setup_ctx: tuple[Context, Counter], promise_hook: Case):
    ctx, counter = setup_ctx
    ret = ctx.eval(promise_hook.code)
    assert isinstance(ret, Promise)
    assert counter.is_equal_to(*promise_hook.expected)
