from .quickjs cimport *
from cpython.bytes cimport PyBytes_FromStringAndSize
from cpython.unicode cimport PyUnicode_FromString, PyUnicode_FromStringAndSize
from cpython.exc cimport PyErr_NoMemory, PyErr_SetObject, PyErr_WriteUnraisable
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from cpython.long cimport PyLong_FromString, PyLong_AsLongAndOverflow
from cpython.bool cimport PyBool_FromLong
from cpython.buffer cimport PyObject_CheckBuffer
from cpython.tuple cimport PyTuple_GET_SIZE
from cpython.list cimport PyList_AsTuple
from cpython.object cimport PyObject_CallObject

cdef extern from "Python.h":
    # tweaked signature just a little for our purposes...
    object PyTuple_GET_ITEM(object p, Py_ssize_t pos)
    JSValue CYJS_ThrowException(JSContext* ctx, const char* msg)
    void Py_XDECREF(object)



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
            JS_FreeValue(ctx, value)

        if stack_cstring != NULL:
            JS_FreeCString(ctx, stack_cstring)    
            JS_FreeValue(ctx, stack)

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


# JS Python function inspired by the Old QuickJS Python library
# cdef class JSPyFunction:
#     cdef:
#         # Might have it carry runtime parent as a means
#         # of preventing immediate gc from taking over...
#         readonly Runtime rt
#         object func
#         JSValue val

#     cdef object call(self, Context ctx, JSValue* argv, int argc):
#         cdef arg_parser_t p
#         cdef tuple py_args
#         # since were unpacking to python we say
#         # to the arg_parser that len is filled also...
#         # this will not attempt to put objects on the heap if 
#         # done so correctly.. 

#         # will have whatever the thrown exception be to be handled
#         # via jspy_func_call named after js2py
#         arg_parser_init(&p, ctx.ctx, argv, argc, argc)
#         try:
#             py_args = arg_parser_unpack(&p)
#             return PyObject_CallObject(self.func, py_args)
#         finally:
#             arg_parser_finish(&p)



# TODO: Asynchronous capabilities planned as soon as they can be
# figured out, for now only regular functions are acceptable...
# a wrapper for asynchronous capabilities to make things easier is aiojs

# cdef JSValue jspy_func_call(JSContext *ctx, JSValue func_obj,
#     JSValue this_val, int argc, JSValue *argv, int unused_flags) noexcept with gil:
#     cdef str err_msg
#     cdef Py_buffer err_view
#     cdef Context context = <Context>(JS_GetContextOpaque(ctx))
#     cdef JSPyFunction fn = <JSPyFunction>(JS_GetOpaque(func_obj, context.runtime.py_function_id))
#     cdef JSValue ret = JS_NULL # just incase of a crash
#     cdef object py_ret
#     try:
#         py_ret = fn.call(context, argv, argc)
#         if to_quickjs(ctx, &ret, py_ret) < 0:
#             raise
#         return ret

#     # TODO: KeyboardInterrupt system?
#     except Exception as e:
#         try:
#             err_msg = str(e)
#             if cyjs_get_buffer(err_msg, &err_view) < 0:
#                 return CYJS_ThrowException(ctx, "Unable to throw Python Exception due to failure with the exception")
#             ret = CYJS_ThrowException(ctx, <const char*>err_view.buf)
#             cyjs_release_buffer(&err_view)

#         except Exception:
#             return CYJS_ThrowException(ctx, "Unable to throw Python Exception due to failure with the exception")


# cdef void jspy_func_finalizer(JSRuntime* rt, JSValue val) noexcept with gil:
#     cdef Runtime pyrt = <Runtime>JS_GetRuntimeOpaque(rt)
#     cdef JSPyFunction js2py = JS_GetOpaque(val, pyrt.py_function_id)
#     # This is probably the best we can do as in terms of Object deletion
#     Py_XDECREF(js2py)





# Todo: allow Name Overriding feature to evade captcha solver failures
# cdef void js_python_func_class_init(JSClassDef* d, const char* name):
#     d.name = name
#     d.call = jspy_func_call
#     d.finalizer = jspy_func_finalizer
    

cdef class Runtime:
    def __init__(self) -> None:
        self.rt = CYJS_NewRuntime(<void*>self)
        
        # just needed for bridging w/ python. We can add discrete settings for
        # webscraping a bit later...
        # js_python_func_class_init(&self.py_function_class_def, "JS2PYFunction")
        # JS_NewClassID(self.rt, &self.py_function_id)
        # JS_NewClass(self.rt, &self.py_function_class_def)


    cpdef MemoryUsage compute_memory_usage(self):
        cdef JSMemoryUsage mu
        JS_ComputeMemoryUsage(self.rt, &mu)
        return MemoryUsage.new(&mu)

    cpdef object dump_memory_usage(self, object file):
        if CYJS_DumpMemoryUsage(self.rt, file) < 0:
            raise

    cpdef object execute_pending_job(self):
        cdef JSContext* ctx = NULL
        if self.is_job_pending():
            if JS_ExecutePendingJob(self.rt, &ctx) < 0:
                self.raise_exception()
                return None
            return <Context>JS_GetContextOpaque(ctx)
        return None

    
    cpdef bint is_job_pending(self):
        return JS_IsJobPending(self.rt)
    
    cdef JSContext* new_context(self) except NULL:
        cdef JSContext* ctx = JS_NewContext(self.rt)
        if ctx == NULL:
            PyErr_NoMemory()
        return ctx

    cpdef void run_gc(self):
        """
        Runs QuickJS-NG's internal Garbage Collector
        
        **Warning!** Use at your own risk.
        """
        JS_RunGC(self.rt)

    cpdef void set_memory_limit(self, size_t limit):
        JS_SetMemoryLimit(self.rt, limit)

    cpdef void set_max_stack_size(self, size_t max_stack_size):
        JS_SetMaxStackSize(self.rt, max_stack_size)

    cpdef void update_statck_top(self):
        JS_UpdateStackTop(self.rt)
    
    
   
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
# ctypedef fused cyjs_object_t:
#     object
#     Object

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

cdef inline int fast_serlize_string(JSContext* ctx, JSValue* val, object obj):
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



# Returns -1 on failre as a failsafe for C to evacuate safely from
cdef int to_quickjs(JSContext* ctx, JSValue* val, object obj) noexcept:
    # Start with the best case scenario
    cdef int overflow = 0
    cdef long ival
    
    if isinstance(obj, Object):
        val[0] = (<Object>obj).value
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
    
    elif isinstance(obj, str) or PyObject_CheckBuffer(obj):
        return fast_serlize_string(ctx, val, obj)
    
    elif isinstance(obj, (dict, list)):
        return fast_serlize_dict_or_list(ctx, val, obj)

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
cdef tuple arg_parser_unpack(arg_parser_t* self):
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


cdef class Object:

    cdef void init(self, Context ctx, JSValue value):
        self.context = ctx
        self.value = value
        self.ctx = ctx.ctx

    cpdef bytes to_json(self):
        """
        Useful when debugging or handling unknown js to py conversions
        NOTE: for best results, using third party libraries like orjson 
        or msgspec is advised. 
        """
        cdef JSValue v = JS_JSONStringify(self.ctx, self.value, JS_UNDEFINED, JS_UNDEFINED)
        cdef size_t size
        cdef const char* data = JS_ToCStringLen(self.ctx, &size, self.value)
        cdef bytes ret = PyBytes_FromStringAndSize(data, size)
        JS_FreeCString(self.ctx, data)
        return ret

    # serves for debugging type tags
    @property
    def tag(self):
        return JS_VALUE_GET_TAG(self.value)


    def get(self, key, *args):
        if len(args) > 1:
            raise RuntimeError("Wrong number of arguments expected <= 2 got %i" % len(args))

        cdef JSValue v
        cdef JSAtom atom
        cdef JSContext* ctx = self.ctx

        # raise exception if hit
        if py_to_atom(ctx, key, &atom) < 0:
            raise
        
        v = JS_GetProperty(ctx, self.value, atom)
        if JS_IsException(v):
            if len(args) < 1:
                raise KeyError(key)
            else:
                # get default
                return args[0]

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

# cdef class JSFunction:

#     @staticmethod
#     cdef JSFunction new(
#         Context ctx,
#         JSValue value,
#         object func
#     ):
#         cdef JSFunction self = JSFunction.__new__(JSFunction)
#         self.ctx = ctx.ctx
#         self.context = ctx
#         self.value = value
#         if JS_SetOpaque(self.value, <void*>self) < 0:
#             self.context.raise_exception()
#             raise
#         # reverse callback to python
#         self.func = func





cdef class Context:
    def __init__(self, Runtime runtime = Runtime()) -> None:
        self.rt = runtime.rt
        self.ctx = runtime.new_context()
        JS_SetContextOpaque(self.ctx, <void*>self)
        # JS_SetClassProto(self.ctx)
        # we don't access the parent (unless on rare occations)
        self.runtime = runtime


    cdef bint has_exception(self):
        return JS_HasException(self.ctx)

    cdef JSValue get_exception(self):
        return JS_GetException(self.ctx)

    cdef object raise_exception(self):
        if self.has_exception():
            raise JSError.new(self.ctx, self.get_exception())

    # function setup was inspired by rquickjs's EvalOptions struct
    cpdef object eval(
        self, 
        object code, 
        object filename = None,
        # Cython & Python have global as a keyword so a workaround was made
        bint module = True, 
        bint strict = False,
        bint backtrace_barrier = False,
        bint promise = False
    ):
        """evaluates javascript code"""
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
        if self.has_exception():
            self.raise_exception()
            raise
        return to_python(self.ctx, val)
        

    def get_global(self):
        return to_python(self.ctx, JS_GetGlobalObject(self.ctx))

    # also inspired from seeing rquickjs (rust)
    def json_parse(self, object json):
        cdef JSValue ret
        cdef Py_buffer view
        if cyjs_get_buffer(json, &view) < 0:
            raise
        ret = JS_ParseJSON(self.ctx, <const char*>view.buf, view.len, b"<input>")
        cyjs_release_buffer(&view)
        # it will be transformed to a Object as needed instead of typical python
        return to_python(self.ctx, ret)

    



    

    # TODO: Soon as I figure out how to make callbacks and promises work...
    # Another library called aiojs plans to be worked on work making python's asyncio
    # with quickjs work happily together.

    # def promise(self):
        # JS_NewPromiseCapability(self.ctx, )

    



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

    elif JS_IsPromise(value):
        return jsv_to_promise(ctx, value)

    elif tag == JS_TAG_MODULE or tag == JS_TAG_OBJECT or tag == JS_TAG_SYMBOL:
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






