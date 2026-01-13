from cyjs import Context

def test_global_eval(ctx: Context) -> None:
    ctx.eval('globalThis.x = "Vizonex";', strict=True)
    assert ctx.get_global().get("x") == "Vizonex"
