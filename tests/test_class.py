import pytest

from cyjs import Context, JSClass, Runtime


def test_new_class(rt: Runtime) -> None:
    class X:
        pass

    js_cls = rt.new_class(X)
    assert isinstance(js_cls, JSClass)
    assert js_cls.name == "X"
    assert js_cls.id != 0
    assert js_cls.type == X
    assert js_cls.runtime == rt

class Point:
    def __init__(self, x: int, y: int):
        self.x = x
        self.y = y

def test_new_class_with_init(ctx: Context) -> None:
    ctx.add_class(ctx.runtime.new_class(Point))
    point: Point = ctx.eval("new Point(1, 2)")
    assert point.x == 1
    assert point.y == 2


def test_new_class_with_init_exception(ctx: Context) -> None:
    class Point:
        def __init__(self, x: int, y: int):
            self.x = x
            self.y = y

    ctx.add_class(ctx.runtime.new_class(Point))
    with pytest.raises(TypeError):
        # Would be the same as Point(1) in python but new syntax because it allocates memory
        ctx.eval("new Point(1)")


def test_new_class_with_public_attributes(ctx: Context) -> None:
    class Point:
        def __init__(self, x: int, y: int):
            self.x = x
            self.y = y

    ctx.add_class(ctx.runtime.new_class(Point, attrs=("x", "y")))
    x = ctx.eval("let x = new Point(1, 2); x.x")
    assert x == 1
    point: Point = ctx.eval(
        "function doit(){"
        "let point = new Point(10, 2);"
        # Try something hacky to trigger a set attribute
        "point.x = 5;"
        "return point;};"
        "doit()"
    )
    assert point.x == 5
    assert point.y == 2


# TODO: Test subclassing a Python class from Javascript
# Example:
# class ColorPoint extends Point {
#     constructor(x, y, color) {
#         super(x, y);
#         this.color = color;
#     }
#     get_color() {
#         return this.color;
#     }
# }
# def test_with_extension_subclass(ctx: Context) -> None:
