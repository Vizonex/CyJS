from collections.abc import Callable
from enum import IntEnum
from typing import Any, Generic, ParamSpec, TypeVar

_P = ParamSpec("_P")
_T = TypeVar("_T")

class JSError(Exception):
    """Represents Numerous Exceptions raised from CYJS"""

    ...

class MemoryUsage:
    malloc_size: int
    malloc_limit: int
    memory_used_size: int
    malloc_count: int
    memory_used_count: int
    atom_count: int
    atom_size: int
    str_count: int
    str_size: int
    obj_count: int
    obj_size: int
    prop_count: int
    prop_size: int
    shape_count: int
    shape_size: int
    js_func_count: int
    js_func_size: int
    js_func_code_size: int
    js_func_pc2line_count: int
    array_count: int
    fast_array_count: int
    fast_array_elements: int
    binary_object_count: int
    binary_object_size: int

class PromiseHookType(IntEnum):
    INIT = 0
    BEFORE = 1
    AFTER = 2
    RESOLVE = 3

INIT: PromiseHookType = ...
BEFORE: PromiseHookType = ...
AFTER: PromiseHookType = ...
RESOLVE: PromiseHookType = ...

class Runtime:
    def __init__(self) -> None: ...
    def compute_memory_usage(self) -> Any: ...
    def dump_memory_usage(self, file: object) -> object: ...
    def execute_pending_job(self) -> object: ...
    def is_job_pending(self) -> bool: ...
    def run_gc(self) -> Any:
        """
        Runs QuickJS-NG's internal Garbage Collector

        **Warning!** Use at your own risk.
        """
        ...

    def set_memory_limit(self, limit: int) -> Any: ...
    def set_max_stack_size(self, max_stack_size: int) -> Any: ...
    def update_statck_top(self) -> Any: ...
    def set_promise_hook(
        self,
        func: Callable[["Context", PromiseHookType, Promise, Promise | None], None],
    ) -> object: ...

class _OView:
    def __init__(self, obj: Object) -> None: ...
    def __len__(self):  # -> unsigned int:
        ...

class _ObjectItemsView(_OView):
    def __iter__(self):  # -> Generator[tuple[object, object], None, None]:
        ...

class _ObjectKeysView(_OView):
    def __iter__(self):  # -> Generator[object, None, None]:
        ...
    def __contains__(self, key: object):  # -> bool:
        ...

class _ObjectValuesView(_OView):
    def __iter__(self):  # -> Generator[object, None, None]:
        ...
    def __contains__(self, value: object):  # -> bool:
        ...

class Object:
    def to_json(self) -> bytes:
        """
        Useful when debugging or handling unknown js to py conversions
        NOTE: for best results, using third party libraries like orjson
        or msgspec are advised.
        """
        ...

    @property
    def tag(self):  # -> signed int:
        ...
    def get(self, key):  # -> object:
        ...
    def set(self, key: object, value: object):  # -> None:
        ...
    def __call__(self, *args):  # -> object:
        ...
    def invoke(self, func: object, *args):  # -> object:
        ...
    def items(self) -> _ObjectItemsView: ...
    def values(self) -> _ObjectValuesView: ...
    def keys(self) -> _ObjectKeysView: ...

    # equivlent to context.eval_this(self)
    def eval(
        self,
        code: str | bytes | bytearray | memoryview,
        filename: object = ...,
        strict: bool = ...,
        backtrace_barrier: bool = ...,
        promise: bool = ...,
    ) -> object:
        """evaluates javascript code"""
        ...

    def eval_module(
        self,
        code: str | bytes | bytearray | memoryview,
        filename: object = ...,
        strict: bool = ...,
        backtrace_barrier: bool = ...,
        promise: bool = ...,
    ) -> object:
        """evaluates javascript module code"""
        ...

class JSFunction(Generic[_P, _T]):
    context: Context

    def __call__(self, *args: _P.args, **kwargs: _P.kwargs) -> _T: ...
    @property
    def object(self) -> Object:
        pass

class Context:
    def __init__(
        self,
        runtime: Runtime = ...,
        base_objects: bool = ...,
        date: bool = ...,
        intrinsic_eval: bool = ...,
        regexp_compiler: bool = ...,
        regexp: bool = ...,
        json: bool = ...,
        proxy: bool = ...,
        map_set: bool = ...,
        typed_arrays: bool = ...,
        bigint: bool = ...,
        weak_ref: bool = ...,
        performance: bool = ...,
        dom_exception: bool = ...,
        promise: bool = ...,
    ) -> None: ...
    def eval(
        self,
        code: str | bytes,
        filename: object = ...,
        strict: bool = ...,
        backtrace_barrier: bool = ...,
        promise: bool = ...,
    ) -> object:
        """evaluates javascript code"""
        ...

    def eval_module(
        self,
        code: str | bytes,
        filename: object = ...,
        strict: bool = ...,
        backtrace_barrier: bool = ...,
        promise: bool = ...,
    ) -> object:
        """evaluates javascript module code"""
        ...

    def get_global(self) -> Object: ...
    def json_parse(self, json: object) -> Object: ...
    def get(self, name: bytes | str) -> Object | Any:
        """Implements a Shortcut for converting a global object to a python
        object and setting a value to utilize
        off of."""
        ...

    def set(
        self, name: bytes | str, item: object | Object | Promise | JSFunction
    ) -> None:
        """Sets an item to the current globalThis object"""
        ...

    def add_function(
        self, func: Callable[_P, _T], name: str | bytes | None = None, magic: int = 11
    ) -> JSFunction[_P, _T]:
        """adds a python function to quickjs using
        `JS_NewCClosure` since Quickjs-ng doesn't have
        a good way for bidning python fucntions well yet

        :param func: the python function to invoke with
            quickjs note: that it may not pass along keyword arguments `**kw`
        :param name: an alternative name to give to the function being passed
        :param magic: the magic value of the js function (Not much is known about it
            at the moment... defaults to 11 which reflects quickjs's own tests)
        """

    def eval_this(
        self,
        code: str | bytes | bytearray | memoryview,
        this: Object | Any,
        filename: object = ...,
        strict: bool = ...,
        backtrace_barrier: bool = ...,
        promise: bool = ...,
    ) -> Any: ...
    def eval_this_with_module(
        self,
        code: str | bytes | bytearray | memoryview,
        this: Object | Any,
        filename: object = ...,
        strict: bool = ...,
        backtrace_barrier: bool = ...,
        promise: bool = ...,
    ) -> Any: ...

class CancelledError(Exception):
    """Promise was rejected"""

    ...

class InvalidStateError(Exception):
    """Promise on inavlid state"""

    ...

class Promise(Object):
    def add_done_callback(self, fn: Callable[["Promise"], None]) -> object:
        """Attaches a callable callback when promise finishes or raises an exception"""
        ...

    def exception(self) -> BaseException: ...
    def done(self) -> bool: ...
    def remove_done_callback(self, fn: Callable[["Promise"], None]) -> int:
        """Remove all instances of a callback from the "call when done" list.

        Returns the number of callbacks removed.
        """
        ...

    def result(self) -> Any: ...
    def poll(self) -> Any:
        """Polls QuickJS Eventloop a single cycle while attempting
        to wait for this Promise to complete"""
        ...
