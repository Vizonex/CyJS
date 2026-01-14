from cyjs._cyjs import Context, Runtime

import pytest


@pytest.fixture()
def rt():
    return Runtime()


@pytest.fixture(scope="function", autouse=True)
def ctx() -> Context:
    return Context()
