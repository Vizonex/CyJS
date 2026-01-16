import pytest

from cyjs._cyjs import Context


# oldest trick in the book...
def add(a: int, b: int) -> int:
    return a + b


# TODO:
# def peform_raise():
#     raise RuntimeError("I'm a teapot")


def test_cclosure_eval(ctx: Context) -> None:
    func = ctx.add_function(add, "add")
    ctx.set("add", func)
    result = ctx.eval("globalThis.add(1, 2)")
    assert result == 3


def throw_exception():
    raise RuntimeError("Boo")


def test_function_that_raises_exception(ctx: Context):
    func = ctx.add_function(throw_exception, "py_throw_exception")
    ctx.set("py_throw", func)

    # The lower level gets the worm in this case since python does better with python
    # and Javascript does better with Javascript.
    with pytest.raises(RuntimeError, match=r"Boo"):
        ctx.eval("globalThis.py_throw()")
