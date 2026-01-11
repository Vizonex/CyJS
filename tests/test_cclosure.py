from cyjs._cyjs import Context

import pytest

# oldest trick in the book...
def add(a: int, b:int) -> int:
    return a + b

@pytest.fixture(scope="function")
def ctx() -> Context:
    return Context()

def test_cclosure_eval(ctx: Context) -> None:
    func = ctx.add_function(add, "add")
    ctx.set("add", func)
    result = ctx.eval("globalThis.add(1, 2)", module=False)
    assert result == 3
    


