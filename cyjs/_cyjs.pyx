# cython: freethreading_compatible = True
from cpython.bool cimport PyBool_FromLong
from cpython.buffer cimport PyObject_CheckBuffer
from cpython.bytes cimport PyBytes_FromStringAndSize
from cpython.exc cimport (PyErr_CheckSignals, PyErr_NoMemory, PyErr_Occurred,
                          PyErr_SetObject, PyErr_WriteUnraisable)
from cpython.list cimport PyList_AsTuple
from cpython.long cimport PyLong_AsLongAndOverflow, PyLong_FromString
from cpython.mem cimport PyMem_Free, PyMem_Malloc, PyMem_Realloc
from cpython.object cimport PyObject_CallObject, PyObject_Str
from cpython.tuple cimport PyTuple_GET_SIZE
from cpython.unicode cimport PyUnicode_FromString, PyUnicode_FromStringAndSize

from .quickjs cimport *


cdef extern from "Python.h":
    # tweaked signature just a little for our purposes...
    object PyTuple_GET_ITEM(object p, Py_ssize_t pos)
    # hacky REFs to not need a linked list setup like with the old quickjs library
    void Py_XDECREF(object)
    void Py_XINCREF(object)



cimport cython

# TODO: I'm writing a new cython utils library and a yyjson writer would be a good use-case here...

import json


cdef class JSError(Exception):
    """Represents Numerous Exceptions raised from CYJS"""

    @staticmethod
    cdef JSError new(JSContext* ctx, JSValue value):
        cdef JSError err
        cdef const char* cstring = JS_ToCString(ctx, value)
        cdef const char* stack_cstring = NULL
        cdef JSValue stack = JS_NULL

        if not (JS_IsNull(value) or JS_IsUndefined(value)):
            stack = JS_GetPropertyStr(ctx, value, "stack")
            if not JS_IsException(stack):
                stack_cstring = JS_ToCString(ctx, stack)

        err = JSError(
            PyUnicode_FromString(cstring) if cstring != NULL else None,
            PyUnicode_FromString(stack_cstring) if stack_cstring != NULL else None
        )
        if cstring != NULL:
            JS_FreeCString(ctx, cstring)

        if stack_cstring != NULL:
            JS_FreeCString(ctx, stack_cstring)
            JS_FreeValue(ctx, stack)

        JS_FreeValue(ctx, value)
        return err


@cython.final
cdef class MemoryUsage:

    @staticmethod
    cdef MemoryUsage new(const JSMemoryUsage *ptr):
        cdef MemoryUsage self = MemoryUsage.__new__(MemoryUsage)
        self.malloc_size = ptr.malloc_size
        self.malloc_limit = ptr.malloc_limit
        self.memory_used_size = ptr.memory_used_size
        self.malloc_count = ptr.malloc_count
        self.memory_used_count = ptr.memory_used_count
        self.atom_count = ptr.atom_count
        self.atom_size = ptr.atom_size
        self.str_count = ptr.str_count
        self.str_size = ptr.str_size
        self.obj_count = ptr.obj_count
        self.obj_size = ptr.obj_size
        self.prop_count = ptr.prop_count
        self.prop_size = ptr.prop_size
        self.shape_count = ptr.shape_count
        self.shape_size = ptr.shape_size
        self.js_func_count = ptr.js_func_count
        self.js_func_size = ptr.js_func_size
        self.js_func_code_size = ptr.js_func_code_size
        self.js_func_pc2line_count = ptr.js_func_pc2line_count
        self.array_count = ptr.array_count
        self.fast_array_count = ptr.fast_array_count
        self.fast_array_elements = ptr.fast_array_elements
        self.binary_object_count = ptr.binary_object_count
        self.binary_object_size = ptr.binary_object_size
        return self



cdef void on_promise_hook(JSContext *ctx, JSPromiseHookType type,
    JSValue promise, JSValue parent_promise, void *opaque) noexcept with gil:
    cdef PromiseHook hook = <PromiseHook>opaque
    hook.hook(
        ctx, type, promise, parent_promise
    )

cpdef enum PromiseHookType:
    INIT = 0
    BEFORE = 1
    AFTER = 2
    RESOLVE = 3

@cython.internal
cdef class PromiseHook:
    @staticmethod
    cdef PromiseHook new(Runtime rt, object func):
        cdef PromiseHook self = PromiseHook.__new__(PromiseHook)
        self.func = func
        self.rt = rt
        return self

    cdef void hook(self, JSContext *context, JSPromiseHookType type,
        JSValue promise, JSValue parent_promise) noexcept:
        cdef Context ctx = <Context>JS_GetContextOpaque(context)
        try:
            # Convert promiseHook to a public version and 
            # convert all objects to python acceptable types before sending and ensure nothing can crash via duping the object
            PyObject_CallObject(self.func, (ctx, <PromiseHookType>type,  to_python(context, JS_DupValue(context, promise)), to_python(context, JS_DupValue(context, parent_promise))))
        except BaseException as e:
            # We can regain this exception later if grabbed immediately...
            ctx._cb_exception = e


# TODO: PromiseRejectionTracker when figured out how to test it right...
# cdef void on_promise_rejection_tracker_hook(JSContext*, JSValue, JSValue, bint, void* opaque) noexcept with gil:
# @cython.internal
# cdef class PromiseRejectionTracker:


cdef class Runtime:
    def __init__(self) -> None:
        self.rt = CYJS_NewRuntime(<void*>self)
        # We can set this attribute up later...
        self.has_promise_hook = False

    cpdef MemoryUsage compute_memory_usage(self):
        cdef JSMemoryUsage mu
        JS_ComputeMemoryUsage(self.rt, &mu)
        return MemoryUsage.new(&mu)

    cpdef object dump_memory_usage(self, object file):
        if CYJS_DumpMemoryUsage(self.rt, file) < 0:
            raise

    cpdef object execute_pending_job(self):
        cdef JSContext* ctx = NULL
        cdef Context py_context
        if self.is_job_pending():
            if JS_ExecutePendingJob(self.rt, &ctx) < 0:
                self.raise_exception()
                return None
            
            py_context = <Context>JS_GetContextOpaque(ctx)
            if py_context._cb_exception:
                raise py_context._cb_exception
        return None


    cpdef bint is_job_pending(self):
        return JS_IsJobPending(self.rt)

    cdef JSContext* new_context(self) except NULL:
        # Use a raw context to enable higher performance when we can disable things...
        cdef JSContext* ctx = JS_NewContextRaw(self.rt)
        if ctx == NULL:
            PyErr_NoMemory()
        return ctx

    cpdef void run_gc(self):
        """
        Runs QuickJS-NG's internal Garbage Collector

        **Warning!** Use at your own risk.
        """
        JS_RunGC(self.rt)

    # While I would go ahead start to inline these, python also needs a way to call them...
    cpdef void set_memory_limit(self, size_t limit):
        JS_SetMemoryLimit(self.rt, limit)

    cpdef void set_max_stack_size(self, size_t max_stack_size):
        JS_SetMaxStackSize(self.rt, max_stack_size)

    cpdef void update_statck_top(self):
        JS_UpdateStackTop(self.rt)

    cpdef object set_promise_hook(self, object func):
        if not callable(func):
            raise TypeError("Promise hook must be callable.")
        self.promise_hook = PromiseHook.new(self, func)
        self.has_promise_hook = True
        JS_SetPromiseHook(self.rt, on_promise_hook, <void*>self.promise_hook)


    def __dealloc__(self):
        if self.rt != NULL:
            JS_FreeRuntime(self.rt)

cdef int py_to_atom(JSContext* ctx, object val, JSAtom* at) except -1:
    cdef Py_buffer view
    if isinstance(val, Object):
        at[0] = JS_ValueToAtom(ctx, (<Object>val).value)
    elif isinstance(val, int):
        at[0] = JS_NewAtomUInt32(ctx, <uint32_t>val)
    else:
        if cyjs_get_buffer(val, &view) < 0:
            return -1
        atom = JS_NewAtomLen(ctx, <const char*>view.buf, view.len)
        cyjs_release_buffer(&view)
        if atom == 0:
            PyErr_SetObject(JSError, "Failed to convert python value to JSAtom")
            return -1
        at[0] = atom
    return 0

cdef object atom_to_py(JSContext* ctx, JSAtom at):
    cdef size_t size
    cdef const char* c_str = JS_AtomToCStringLen(ctx, &size, at)
    try:
        return PyUnicode_FromStringAndSize(c_str, <Py_ssize_t>size)
    finally:
        JS_FreeCString(ctx, c_str)

# TODO: Planned for to_quickjs to speedup certain funtions
# soon as I can get around to testing it...

# this gets used quite a few times hence inlining it felt
# like the best choice of apporch
cdef inline int fast_parse_json_from_obj(JSContext* ctx, JSValue* val, object obj) noexcept:
    cdef Py_buffer view
    cdef JSValue value

    if cyjs_get_buffer(obj, &view) < 0:
        return -1
    value = JS_ParseJSON(ctx, <const char*>view.buf, <size_t>view.len, b"<input>")
    cyjs_release_buffer(&view)
    if JS_IsException(value):
        return -1
    # same as *val = value in C since were just saying pick up this address please.
    val[0] = value
    return 0


cdef inline int fast_serlize_dict_or_list(JSContext* ctx, JSValue* val, object obj) noexcept:
    try:
        # TODO: Try using an external json cython library for this
        # in the future (I think I had a yyjson thingy somewhere
        # and a rewrite of that project to become cython-only might
        # do well here)
        return fast_parse_json_from_obj(ctx, val, json.dumps(obj))
    except BaseException:
        # reraise later...
        return -1


cdef int fast_serlize_string(JSContext* ctx, JSValue* val, object obj):
    cdef Py_buffer view
    cdef JSValue value

    if cyjs_get_buffer(obj, &view) < 0:
        return -1
    value = JS_NewStringLen(ctx, <const char*>view.buf, <size_t>view.len)
    cyjs_release_buffer(&view)
    if JS_IsException(value):
        return -1
    val[0] = value
    return 0


cdef inline JSValue py_to_js_exception(JSContext* ctx, object obj):
    cdef Py_buffer view
    cdef JSValue value
    cdef str msg = PyObject_Str(obj)
    if cyjs_get_buffer(msg, &view) < 0:
        return CYJS_ThrowException(ctx, "Unable to create exception from a string object")
    value = CYJS_ThrowException(ctx, <const char*>view.buf)
    cyjs_release_buffer(&view)
    return value


# Returns -1 on failre as a failsafe for C to evacuate safely from
# TODO: Optimize under this logic -> 
cdef int to_quickjs(JSContext* ctx, JSValue* val, quickjs_type_t obj) noexcept:
    # Start with the best case scenario
    cdef int overflow = 0
    cdef long ival

    # NOTE: We optimize by this logic before attempting to perform fallback
    # https://cython.readthedocs.io/en/latest/src/userguide/fusedtypes.html#type-checking-specializations
    if quickjs_type_t is Object:
        val[0] = (<Object>obj).value
        return 0
    elif quickjs_type_t is JSFunction:
        val[0] = (<JSFunction>obj).value
        return 0

    elif quickjs_type_t is Exception:
        val[0] = py_to_js_exception(ctx, obj)
        return 0
    
    elif quickjs_type_t is dict:
        return fast_serlize_dict_or_list(ctx, val, obj)

    elif quickjs_type_t is list:
        return fast_serlize_dict_or_list(ctx, val, obj)

    elif quickjs_type_t is str:
        return fast_serlize_string(ctx, val, obj)
    
    elif quickjs_type_t is int:
        val[0] = JS_NewInt32(ctx, obj)
        return 0

    elif quickjs_type_t is bint:
        val[0] = JS_NewBool(ctx, <bint>obj)
        return 0

    else:
        # fallback route
        # Important NOTE:

        # we handle all type checks first this is why we don't do 
        # elif isintance(obj, str) or PyObject_CheckBuffer(obj):
        # as we want all fused types to have a clear path if they 
        # can all be reached the final case (which should be just PyObject*) 
        # can have PyObject_CheckBuffer(obj) since these aren't clearly explained.

        if isinstance(obj, Object):
            val[0] = (<Object>obj).value
            return 0
        elif isinstance(obj, JSFunction):
            # very quick shortcut
            val[0] = (<JSFunction>obj).value
            return 0

        elif isinstance(obj, Exception):
            # Convert exception
            val[0] = py_to_js_exception(ctx, obj)
            return 0

        elif isinstance(obj, bool):
            val[0] = JS_NewBool(ctx, <bint>obj)
            return 0

        elif isinstance(obj, int):
            ival = PyLong_AsLongAndOverflow(obj, &overflow)
            if overflow:
                return fast_parse_json_from_obj(ctx, val, repr(obj))
            val[0] = JS_NewInt32(ctx, ival)
            return 0

        elif isinstance(obj, float):
            val[0] = JS_NewFloat64(ctx, <double>obj)
            return 0

        elif isinstance(obj, str):
            return fast_serlize_string(ctx, val, obj)

        elif isinstance(obj, (dict, list)):
            return fast_serlize_dict_or_list(ctx, val, obj)

        elif PyObject_CheckBuffer(obj):
            return fast_serlize_string(ctx, val, obj)

    PyErr_SetObject(TypeError, f"unknown object {type(obj).__name__!r}")
    return -1





# Argument parser (Not public)

cdef struct arg_parser_t:
    Py_ssize_t size # heap size
    Py_ssize_t len # objects held
    JSValue* values # objects
    JSContext* ctx # js context
    bint heap # realloc was called.

# does both incomming and outgoing python and js values
# in both directions
cdef void arg_parser_init(arg_parser_t* self, JSContext* ctx, JSValue* values, Py_ssize_t size, Py_ssize_t len):
    self.ctx = ctx
    self.values = values
    self.size = size
    self.len = len
    self.heap = 0


cdef int arg_parser_append(arg_parser_t* self, JSValue val):
    cdef Py_ssize_t new_size
    cdef JSValue* new_values
    if self.len >= self.size:
        new_size = self.size * 2
        new_values = <JSValue*>js_realloc(self.ctx, self.values, new_size * sizeof(JSValue))
        if new_values == NULL:
            PyErr_NoMemory()
            return -1
        self.heap = 1
        self.values = new_values
        self.size = new_size

    self.values[self.len] = val
    self.len += 1
    return 0

cdef int arg_parser_pack(arg_parser_t* self, tuple args):
    cdef Py_ssize_t i
    cdef Py_ssize_t size = PyTuple_GET_SIZE(args)
    cdef JSValue val

    for i in range(size):
        if to_quickjs(self.ctx, &val, PyTuple_GET_ITEM(args, i)) < 0:
            return -1
        if JS_IsException(val):
            return -1
        if arg_parser_append(self, val) < 0:
            return -1
    return 0

# While being Python error handled this parser does the reverse to pack
# when handling incoming objects.
cdef inline tuple arg_parser_unpack(arg_parser_t* self):
    cdef Py_ssize_t i
    cdef list args = [to_python(self.ctx, JS_DupValue(self.ctx, self.values[i])) for i in range(self.len)]
    return PyList_AsTuple(args)


cdef void arg_parser_finish(arg_parser_t* self):
    cdef Py_ssize_t i
    # Free them all...
    for i in range(self.len):
        JS_FreeValue(self.ctx, self.values[i])

    if self.heap:
        # if we had ownership over a heap (mostly in python -> js cases)
        # free the heap.
        js_free(self.ctx, self.values)


# base for gathering iterations
cdef class _OView:
    cdef:
        # parent object to prevent GC
        Object obj
        JSValue value
        JSPropertyEnum* tab
        JSContext* ctx
        uint32_t len

    def __init__(self, Object obj):
        if JS_GetOwnPropertyNames(obj.ctx, &self.tab, &self.len, obj.value, JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY) < 0:
            if obj.context.has_exception():
                obj.context.raise_exception()
                raise
            else:
                raise RuntimeError("failed to get object's Property names")

        self.obj = obj
        self.ctx = obj.ctx
        self.value = obj.value

    # Mainly used with items and values not keys
    # it has simillar usage to PyDict_Next
    # this will not raise exceptions, so be very careful when using it...
    cdef bint cnext(self, size_t* pos, JSAtom* key, JSValue* val):
        cdef JSAtom at
        cdef size_t _pos = pos[0]
        if _pos > self.len:
            return 0

        at = self.tab[_pos].atom
        # Cython can't do *val so try val[0] instead
        val[0] = JS_GetProperty(self.ctx, self.value, at)
        key[0] = at
        pos[0] = _pos + 1
        return 1

    def __dealloc__(self):
        if self.tab != NULL:
            js_free(self.ctx, self.tab)

    def __len__(self):
        return self.len


cdef class _ObjectItemsView(_OView):
    def __iter__(self):
        cdef JSAtom key
        cdef JSValue val
        cdef size_t pos = 0

        while self.cnext(&pos, &key, &val):
            yield (atom_to_py(self.ctx, key), to_python(self.ctx, val))


cdef class _ObjectKeysView(_OView):
    def __iter__(self):
        cdef size_t i
        for i in range(self.len):
            yield atom_to_py(self.ctx, self.tab[i].atom)

    def __contains__(self, object key):
        cdef size_t i
        cdef JSAtom at
        if py_to_atom(self.ctx, key, &at) < 0:
            raise

        for i in range(self.len):
            if self.tab[i].atom == at:
                return True
        return False

cdef class _ObjectValuesView(_OView):
    def __iter__(self):
        cdef JSAtom key
        cdef JSValue val
        cdef size_t pos = 0

        while self.cnext(&pos, &key, &val):
            yield to_python(self.ctx, val)

    def __contains__(self, object value):
        cdef JSAtom key
        cdef JSValue val
        cdef size_t pos = 0

        while self.cnext(&pos, &key, &val):
            if value == to_python(self.ctx, val):
                return True
        return False


# Inspired by Old the & retired Quickjs ObjectData class obejct
cdef class Object:

    cdef void init(self, Context ctx, JSValue value):
        self.context = ctx
        self.value = value
        self.ctx = ctx.ctx
        # make tag a readonly attribute instead of a property so we can get quicker access to it.
        self.tag = JS_VALUE_GET_TAG(self.value)

    cpdef bytes to_json(self):
        """
        Useful when debugging or handling unknown js to py conversions
        NOTE: for best results, using third party libraries like orjson
        or msgspec are advised.
        """
        cdef JSValue v = JS_JSONStringify(self.ctx, self.value, JS_UNDEFINED, JS_UNDEFINED)
        cdef size_t size
        cdef const char* data = JS_ToCStringLen(self.ctx, &size, self.value)
        cdef bytes ret = PyBytes_FromStringAndSize(data, size)
        JS_FreeCString(self.ctx, data)
        return ret

    # serves for debugging type tags

    def get(self, key):

        cdef JSValue v
        cdef JSAtom atom
        cdef JSContext* ctx = self.ctx

        # raise exception if hit
        if py_to_atom(ctx, key, &atom) < 0:
            raise

        v = JS_GetProperty(ctx, self.value, atom)

        # Dup JS_Value because to_python can and will Free information
        return to_python(ctx, JS_DupValue(ctx, v))

    def set(self, object key, object value):
        cdef JSContext* ctx = self.ctx
        cdef JSValue js_value
        cdef JSAtom atom

        if py_to_atom(ctx, key, &atom) < 0:
            raise

        if to_quickjs(ctx, &js_value, value) < 0:
            self.context.raise_exception()
            # raising the second time will be for if python is at fault for this.
            raise

        if JS_IsException(js_value):
            self.context.raise_exception()
            # raising the second time will be for if python is at fault for this.
            raise

        if JS_SetProperty(ctx, self.value, atom, js_value) < 0:
            raise AttributeError(f"Could not set {key} to Object")

    def __call__(self, *args):
        cdef arg_parser_t p
        cdef JSValue values[10]
        cdef JSValue ret
        # we will have 10 free slots with a start position of 0
        arg_parser_init(&p, self.ctx, values, 10, 0)
        try:
            if arg_parser_pack(&p, args) < 0:
                # see if it's QuickJs's Fault otherwise the Fault falls to python
                self.context.raise_exception()
                # raising the second time will be for if python is at fault for this.
                raise

            ret = JS_Call(self.ctx, self.value, JS_NULL, p.len, p.values)

            if JS_IsException(ret):
                self.context.raise_exception()
                # this should almost never occur but if it does do this
                raise JSError("raised exception without it being Quickjs's own fault")
            return to_python(self.ctx, ret)

        finally:
            # Cleanup
            arg_parser_finish(&p)

    def invoke(self, object func, *args):
        cdef JSAtom atom
        cdef JSContext* ctx = self.ctx
        cdef JSValue ret
        cdef JSValue js_args[10]
        cdef arg_parser_t p

        if py_to_atom(ctx, func, &atom) < 0:
            raise

        arg_parser_init(&p, self.ctx, js_args, 10, 0)
        try:
            if arg_parser_pack(&p, args) < 0:
                raise
            ret = JS_Invoke(ctx, self.value, atom, p.len, p.values)
            return to_python(ctx, ret)
        finally:
            arg_parser_finish(&p)


    def __dealloc__(self):
        JS_FreeValue(self.ctx, self.value)

    # Mapping attributes can help with debugging attributes
    def items(self):
        return _ObjectItemsView(self)

    def values(self):
        return _ObjectValuesView(self)

    def keys(self):
        return _ObjectKeysView(self)

    # eval_this functions (proxied for the sake of easier access)

    cpdef object eval(
        self, 
        object code, 
        object filename = None,
        bint strict = False,
        bint backtrace_barrier = False,
        bint promise = False
    ):
        return self.context.ceval_this(code, self, filename, False, strict, backtrace_barrier, promise)

    cpdef object eval_module(
        self, 
        object code, 
        object filename = None,
        bint strict = False,
        bint backtrace_barrier = False,
        bint promise = False
    ):
        return self.context.ceval_this(code, self, filename, True, strict, backtrace_barrier, promise)



# Will use a closure to gain access to this function since there isn't a reasonable 
# way to obtain it elsewhere using a INCREF (on creation) and DECREF (on finalization) respectively... 

cdef JSValue on_cclosure_callback(JSContext *ctx, 
    JSValue this_val, 
    int argc, JSValue *argv,
    int magic, void *func_data) noexcept with gil:
    cdef JSFunction jsfunc = <JSFunction>(func_data)
    return jsfunc.call_js(ctx, this_val, argc, argv, magic)


# TODO: (Vizonex) Check if using INCREF and DECREF Causes memory leaks
# Everyone Else: Feel free to throw an issue if this is casuing memory leaks on your end.
cdef void on_cclosure_opaque_finalize(void *opaque) noexcept with gil:
    cdef JSFunction jsfunc = <JSFunction>opaque
    # Deref it as it possibly means we finished needing it within Quickjs
    Py_XDECREF(jsfunc)


# An async binding for python asynchronous functions might be in consideration for the future
# as part of the aiojs project planned for the future of 2026 - Vizonex
cdef class JSFunction:
    """Used for acting as a bridge between Javascript and Python
    it is meant to be used as an access-point for Javascript (ECMA) to be called upon
    through python. It's not subclassed to Object however due to it's own nature
    but if needed can be accessed from the object property"""


    # Converter for JSFunction
    @staticmethod
    cdef JSFunction new(Context context, object func):
        cdef JSFunction self = JSFunction.__new__(JSFunction)
        self.context = context
        self.ctx = context.ctx
        # NOTE: self.value comes in a bit later...
        self.func = func
        return self

    def __dealloc__(self):
        JS_FreeValue(self.ctx, self.value)

    # quick access shortcut for calling JSFunction as if it were a python function.
    def __call__(self, *args, **kwds):
        return self.func.__call__(self, *args, **kwds)

    @property
    def object(self):
        """Obtains the value as a Javascript Object that could in theory be manipulated
        NOTE: that this calls upon JS_DupValue to prevent derefing the values"""
        return jsv_to_object(self.ctx, JS_DupValue(self.ctx, self.value))

    cdef JSValue call_js(self, JSContext *ctx, JSValue this_val, int argc, JSValue *argv, int magic) noexcept:
        cdef arg_parser_t parser
        cdef tuple args
        cdef object ret
        cdef JSValue js_ret
        arg_parser_init(&parser, ctx, argv, argc, argc)

        try:
            args = arg_parser_unpack(&parser)
            ret = PyObject_CallObject(self.func, args)
            arg_parser_finish(&parser)
            
            if to_quickjs(ctx, &js_ret, ret) < 0:
                raise
            return js_ret

        except Exception as e:
            # set callback exception so python can throw it later...
            self.context._cb_exception = e
            arg_parser_finish(&parser)
            return py_to_js_exception(ctx, e)



        


# cdef class InterruptHandler:
#     @staticmethod
#     cdef InterruptHandler new(Context ctx, object cb):
#         cdef InterruptHandler self = InterruptHandler.__new__(InterruptHandler)
#         self.ctx = ctx
#         self.cb = cb


# we have 2 inlined functions in the pxd definition so we unfortunately have to tell
# the cyright extension to shut up about these which currently are.
#   - has_exception
#   - get_exception

cdef class Context: # type: ignore
    def __init__(self,
        Runtime runtime = Runtime(),
        bint base_objects = True,
        bint date = True,
        bint intrinsic_eval = True,
        bint regexp_compiler = True,
        bint regexp = True,
        bint json = True,
        bint proxy = True,
        bint map_set = True,
        bint typed_arrays = True,
        bint bigint = True,
        bint weak_ref = True,
        bint performance = True,
        bint dom_exception = True,
        bint promise = True
    ) -> None:

        self.rt = runtime.rt
        # TODO: Enable Raw Settings also...
        self.ctx = runtime.new_context()
        JS_SetContextOpaque(self.ctx, <void*>self)
        CYJS_InitalizeSettings(
            self.ctx,
            base_objects,
            date,
            intrinsic_eval,
            regexp_compiler,
            regexp,
            json,
            proxy,
            map_set,
            typed_arrays,
            bigint,
            weak_ref,
            performance,
            dom_exception,
            promise
        )
        
        # we don't access the parent (unless on rare occations but we keep incase of gc or other cases)
        self.runtime = runtime
        # Collection exception if seen in a void callback
        self._cb_exception = None
  

    # Inlined 
    # cdef bint has_exception(self):
    #     return JS_HasException(self.ctx)

    # cdef JSValue get_exception(self):
    #     return JS_GetException(self.ctx)

    # raises exception if one is seen.
    cdef object raise_exception(self):
        cdef object exc 
        if self._cb_exception is not None:
            # Let python exception take over first if seen. it's more accurate than the JSError would be
            exc = self._cb_exception
            self._cb_exception = None
            # Cleanup javascript verison of the given exception since python's 
            # exception would do a better job explaining the problem.
            if JS_HasException(self.ctx):
                JS_FreeValue(self.ctx, JS_GetException(self.ctx))
            raise exc

        if JS_HasException(self.ctx):
            raise JSError.new(self.ctx, self.get_exception())
        
    # function setup was inspired by rquickjs's EvalOptions struct
    cdef object ceval(
        self,
        object code,
        object filename = None,
        # Cython & Python have global as a keyword so a workaround was made
        bint module = True,
        bint strict = False,
        bint backtrace_barrier = False,
        bint promise = False
    ):
        """evaluates javascript code in c"""
        cdef Py_buffer view, fs_view
        cdef JSValue val
        cdef int flags = 0
        cdef object fs =  CYJS_FSConvert(filename) if filename else b"<input>"

        if cyjs_get_buffer(code, &view) < 0:
            raise
        if cyjs_get_buffer(fs, &fs_view) < 0:
            cyjs_release_buffer(&view)
            raise

        flags = JS_EVAL_TYPE_MODULE if module else JS_EVAL_TYPE_GLOBAL
        if strict:
            flags |= JS_EVAL_FLAG_STRICT
        if backtrace_barrier:
            flags |= JS_EVAL_FLAG_BACKTRACE_BARRIER
        if promise:
            flags |= JS_EVAL_FLAG_ASYNC


        val = JS_Eval(
            self.ctx,
            <const char*>view.buf,
            <size_t>view.len,
            <const char*>fs_view.buf,
            flags
        )

        cyjs_release_buffer(&view)
        cyjs_release_buffer(&fs_view)
        
        self.raise_exception()
        
        return to_python(self.ctx, val)

    cpdef object eval(
        self, 
        object code, 
        object filename = None,
        bint strict = False,
        bint backtrace_barrier = False,
        bint promise = False
    ):
        return self.ceval(code, filename, module=False, strict=strict, backtrace_barrier=backtrace_barrier, promise=promise)

    cpdef object eval_module(
        self, 
        object code, 
        object filename = None,
        bint strict = False,
        bint backtrace_barrier = False,
        bint promise = False
    ):
        return self.ceval(code, filename, module=True, strict=strict, backtrace_barrier=backtrace_barrier, promise=promise)
        
    # TODO: Rename to global_object and make it into a @property
    # Otherwise Run JS_GetGlobalObject immediately for duping 
    # and free on __dealloc__ instead.
    def get_global(self):
        return to_python(self.ctx, JS_GetGlobalObject(self.ctx))

    # also inspired from seeing rquickjs (rust) and retired python-quickjs
    def json_parse(self, object json):
        cdef JSValue ret
        cdef Py_buffer view
        if cyjs_get_buffer(json, &view) < 0:
            raise
        ret = JS_ParseJSON(self.ctx, <const char*>view.buf, view.len, b"<input>")
        cyjs_release_buffer(&view)
        # it will be transformed to a Object as needed instead of typical python
        return to_python(self.ctx, ret)


    # from old python-quickjs but with atom conversions instead
    # it's also less steps to convert to an atom before trying.

    # pretty much supporting
    # def get(self, name: bytes | bytearray | array.array | memoryview | str)
    def get(self, object name):
        """Implements a Shortcut for converting a global object to a python object and setting a value to utilize
        off of."""
        cdef JSValue glob, val
        cdef JSAtom atom
        glob = JS_GetGlobalObject(self.ctx)
        if py_to_atom(self.ctx, name, &atom) < 0:
            raise
        val = JS_GetProperty(self.ctx, glob, atom)
        JS_FreeValue(self.ctx, glob)
        return to_python(self.ctx, val)

    def set(self, object name, object item):
        """Sets an item to the current globalThis object"""
        cdef JSValue value
        cdef JSAtom atom
        cdef JSValue glob

        if py_to_atom(self.ctx, name, &atom) < 0:
            raise
        if to_quickjs(self.ctx, &value, item) < 0:
            raise
        glob = JS_GetGlobalObject(self.ctx)
        try:
            if JS_SetProperty(self.ctx, glob, atom, value) < 0:
                raise TypeError("Failed setting the variable.")
        finally:
            JS_FreeValue(self.ctx, glob)
    

    cpdef JSFunction add_function(
        self, 
        object func, 
        object name = None, 
        # incase python function contains dynamic amounts of arguments, 
        # for example: "def func(*args):..."
        int count = -1,
        # personally IDK how this variable works it's just here if someone knows how to use it...
        int magic = 0
        ):
        """adds a python function to quickjs using 
        `JS_NewCClosure` since Quickjs-ng doesn't have 
        a good way for bidning python fucntions well yet
        
        :param func: the python function to invoke with 
            quickjs note: that it may not pass along keyword arguments `**kw`
        :param name: an alternate name to provide the given function
            defaults to obtaining function's name from func.__name__
        :param count: a number of arguments to provide, if count is less than
            zero (0), then functions's __annotations__ will be used to figure that out
                just know that it may fail at inspection since the inspect library 
                is not utilized for the sake of speed.
        :param magic:
            this value is not passed to the python function and is set to zero
            unless internally used with QuickJS this value might be deprecated in the future
        
        """
        cdef object _name
        cdef Py_buffer view
        cdef int argc
        cdef JSValue closure
        cdef JSFunction js_func
        if not callable(func):
            raise TypeError("function must be callable.")

        _name = name or func.__name__

        # Were bindly guessing but in the future, a smarter technique should be gone about
        # Otherwise I'll expand this number to the very maximum number of arguments
        # as python can accept dynamic numbers without question at times...
        argc = <int>len(func.__annotations__) if (count < 0) else count
        

        if cyjs_get_buffer(_name, &view) < 0:
            raise
        try:
        
            js_func = JSFunction.new(self, func)
            closure = JS_NewCClosure(self.ctx, on_cclosure_callback, <const char*>view.buf, on_cclosure_opaque_finalize, argc, magic, <void*>js_func)
            if JS_IsException(closure):
                self.raise_exception()
                raise
            # Have CClosure hold onto it's own reference of js_func if all was successfully implemented
            Py_XINCREF(js_func)
            js_func.value = closure
            return js_func
        
        finally:
            cyjs_release_buffer(&view)
        
    cdef object ceval_this(
        self, 
        object code,
        quickjs_type_t this,
        object filename = None,
        bint module = False, 
        bint strict = False,
        bint backtrace_barrier = False,
        bint promise = False
    ):
        """evaluates javascript code in from another object"""
        cdef Py_buffer view, fs_view
        cdef JSValue val, this_val
        cdef int flags = 0
        cdef object fs =  CYJS_FSConvert(filename) if filename else b"<input>"

        if cyjs_get_buffer(code, &view) < 0:
            raise
        if cyjs_get_buffer(fs, &fs_view) < 0:
            cyjs_release_buffer(&view)
            raise

        flags = JS_EVAL_TYPE_MODULE if module else JS_EVAL_TYPE_GLOBAL
        if strict:
            flags |= JS_EVAL_FLAG_STRICT
        if backtrace_barrier:
            flags |= JS_EVAL_FLAG_BACKTRACE_BARRIER
        if promise:
            flags |= JS_EVAL_FLAG_ASYNC

        if to_quickjs(self.ctx, &this_val, this) < 0:
            raise

        val = JS_EvalThis(
            self.ctx,
            this_val,
            <const char*>view.buf,
            <size_t>view.len,
            <const char*>fs_view.buf,
            flags
        )

        cyjs_release_buffer(&view)
        cyjs_release_buffer(&fs_view)
        
        self.raise_exception()
        
        return to_python(self.ctx, val)

    cpdef object eval_this(
        self, 
        object code,
        object this,
        object filename = None,
        bint strict = False,
        bint backtrace_barrier = False,
        bint promise = False
    ):
        return self.ceval_this(code, this, filename, False, strict, backtrace_barrier, promise)

    cpdef object eval_this_with_module(
        self, 
        object code, 
        object this,
        object filename = None,
        bint strict = False,
        bint backtrace_barrier = False,
        bint promise = False
    ):
        return self.ceval_this(code, this, filename, True, strict, backtrace_barrier, promise)

    # TODO: Soon as I figure out how to make callbacks and promises work...
    # Another library called aiojs plans to be worked on work making python's asyncio
    # with quickjs work happily together.

    # def promise(self):
    #     JS_NewPromiseCapability(self.ctx, )


cdef int py_to_js_str(JSContext* ctx, object obj, JSValue* value):
    cdef Py_buffer view 
    cdef JSValue val
    if cyjs_get_buffer(obj, &view) < 0:
        return -1
    val = JS_NewStringLen(ctx, <const char*>view.buf, <size_t>view.len)
    cyjs_release_buffer(&view)
    value[0] = val
    return 0






cdef object jsv_to_str(JSContext* ctx, JSValue value):
    cdef size_t len
    cdef const char* cstr = JS_ToCStringLen(ctx, &len , value)
    try:
        return PyUnicode_FromStringAndSize(cstr, <Py_ssize_t>len)
    finally:
        JS_FreeCString(ctx, cstr)

cdef object jsv_to_big_int(JSContext* ctx, JSValue value):
    cdef const char* cstr = JS_ToCString(ctx, value)
    try:
        return PyLong_FromString(cstr, NULL, 10)
    finally:
        JS_FreeCString(ctx, cstr)



cdef class CancelledError(Exception):
    """Promise was rejected"""

cdef class InvalidStateError(Exception):
    """Promise on inavlid state"""


cdef class Promise(Object):
    cdef:
        list _callbacks
        object _exception
        object _result
        bint completed

    cpdef object add_done_callback(self, object fn):
        """Attaches a callable callback when promise finishes or raises an exception"""
        if not callable(fn):
            raise TypeError("done callbacks must be callable")

        if JS_PromiseState(self.ctx, self.value) == JS_PROMISE_PENDING:
            self._callbacks.append(fn)
        else:
            fn(self)

    cpdef object exception(self):
        cdef JSPromiseStateEnum state = JS_PromiseState(self.ctx, self.value)
        if state == JS_PROMISE_REJECTED:
            raise CancelledError()
        elif state == JS_PROMISE_PENDING:
            raise InvalidStateError('Result is not ready.')
        return self._exception

    cpdef bint done(self):
        cdef JSPromiseStateEnum state = JS_PromiseState(self.ctx, self.value)
        return state == JS_PROMISE_FULFILLED or state == JS_PROMISE_REJECTED

    # TODO: Figure out how to reject incomming future objects...


    cpdef Py_ssize_t remove_done_callback(self, object fn):
        """Remove all instances of a callback from the "call when done" list.

        Returns the number of callbacks removed.
        """
        cdef Py_ssize_t removed_count
        cdef list filtered_callbacks = [(f, ctx)
                              for (f, ctx) in self._callbacks
                              if f != fn]
        removed_count = <Py_ssize_t>(len(self._callbacks) - len(filtered_callbacks))
        if removed_count:
            self._callbacks[:] = filtered_callbacks
        return removed_count

    cpdef object result(self):
        cdef JSPromiseStateEnum state = JS_PromiseState(self.ctx, self.value)
        if state == JS_PROMISE_REJECTED:
            raise CancelledError()
        if state == JS_PROMISE_FULFILLED:
            if self._exception is not None:
                raise self._exception
            return self._result
        else:
            raise InvalidStateError('Result is not ready.')

    cdef object complete(self):
        cdef JSContext* ctx = self.ctx
        # check if we can skip this step...
        if self.completed == True:
            return

        v = JS_PromiseResult(ctx, self.value)
        if JS_IsException(v):
            self._exception = JSError.new(ctx, v)
        else:
            self._result = to_python(ctx, v)
        for cb in self._callbacks:
            cb(self)
        self.completed = True

    # TODO: might be able to utilize __await__ and __iter__ for polling

    cpdef object poll(self):
        """Polls QuickJS Eventloop a single cycle while attempting
        to wait for this Promise to complete"""
        cdef JSValue v
        cdef JSContext* ctx = self.ctx
        cdef JSRuntime* rt = self.context.rt

        if self.done():
            self.complete()
            return True

        if JS_IsJobPending(rt):
            if JS_ExecutePendingJob(rt, &ctx) < 0:
                self.context.raise_exception()

        if self.done():
            self.complete()
            return True
        else:
            return False



# SENTINAL value (NOT PUBLIC!!!!) It's never used (Only ever once)
# And should not be publically called upon
@cython.internal
cdef class NODEFAULT:
    pass

cdef Object jsv_to_object(JSContext* ctx, JSValue value):
    cdef Object v = Object.__new__(Object)
    v.init(<Context>JS_GetContextOpaque(ctx), value)
    return v

cdef Promise jsv_to_promise(JSContext* ctx, JSValue value):
    cdef Promise v = Promise.__new__(Promise)
    v.init(<Context>JS_GetContextOpaque(ctx), value)
    v._callbacks = []
    v._result = NODEFAULT()
    v._exception = None
    v.completed = False
    return v


cdef object to_python(JSContext* ctx, JSValue value):
    cdef int32_t tag = JS_VALUE_GET_TAG(value)
    cdef object ret

    if tag == JS_TAG_EXCEPTION:
        (<Context>JS_GetContextOpaque(ctx)).raise_exception()
        raise


    elif tag == JS_TAG_MODULE or tag == JS_TAG_OBJECT or tag == JS_TAG_SYMBOL:
        if JS_IsPromise(value):
            return jsv_to_promise(ctx, value)
        return jsv_to_object(ctx, value)
        # pass

    elif tag == JS_TAG_INT:
        ret = JS_VALUE_GET_INT(value)
        JS_FreeValue(ctx, value)
        return ret
    elif tag == JS_TAG_BIG_INT:
        ret = jsv_to_big_int(ctx, value)
        JS_FreeValue(ctx, value)
        return ret
    elif tag == JS_TAG_NULL and tag == JS_TAG_UNDEFINED:
        JS_FreeValue(ctx, value)
        return None
    elif tag == JS_TAG_STRING:
        ret = jsv_to_str(ctx, value)
        JS_FreeValue(ctx, value)
        return ret
    elif tag == JS_TAG_FLOAT64:
        ret = JS_VALUE_GET_FLOAT64(value)
        JS_FreeValue(ctx, value)
        return ret
    elif tag == JS_TAG_BOOL:
        ret = PyBool_FromLong(JS_VALUE_GET_INT(value))
        JS_FreeValue(ctx, value)
        return ret


    # Unimplemented (Hold onto value so we can free it up later)
    return jsv_to_object(ctx, value)


cdef inline object to_python_with_copy(JSContext* ctx, JSValue value):
    """Copies jsvalue before converting it to python useful in cases where
    where JS_DupValue is needed"""
    return to_python(ctx, JS_DupValue(ctx, value))


