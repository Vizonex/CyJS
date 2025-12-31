from .quickjs cimport *
from .context cimport Context

from cpython.exc cimport PyErr_SetObject
from cpython.bool cimport PyBool_FromLong
from cpython.long cimport PyLong_FromString
from cpython.bytes cimport PyBytes_FromStringAndSize
from cpython.unicode cimport PyUnicode_FromStringAndSize, PyUnicode_AsUTF8String

from libc.limits cimport LLONG_MAX
# from cpython.array cimport array
# from array import array

cdef extern from "bridge.h":
    int cyjs_get_buffer(object obj, Py_buffer* view) except -1
    void cyjs_release_buffer(Py_buffer* view)



cdef class Value:
    """
    Represents a JavaScript value which can be a primitive type 
    or an object.
    """

    @staticmethod
    cdef Value from_value(Context ctx, JSValue value):
        cdef Value self = Value.__new__(Value)
        self.ctx = ctx
        self.value = value
        self.tag = JS_VALUE_GET_TAG(value)
        return self

    def __dealloc__(self):
        JS_FreeValue(self.ctx.context, self.value)

    # Going to allow buffer protocol as it's the easiest way to go about
    # bytes conversions...
    def __getbuffer__(self, Py_buffer *buffer, int flags):
        cdef size_t size
        buffer.buf = <void*>JS_ToCStringLen(self.ctx.context, &size, self.value)

        # SEE: https://docs.python.org/3/library/struct.html#format-characters
        buffer.format = 'b' # char
        buffer.internal = NULL
        buffer.itemsize = <Py_ssize_t>size
        buffer.len = <Py_ssize_t>size
        buffer.ndim = 0
        buffer.obj = self
        buffer.readonly = 1 # likely important?
        buffer.shape = NULL
        buffer.strides = NULL
        buffer.suboffsets = NULL
        
    def __releasebuffer__(self, Py_buffer *buffer):
        JS_FreeCString(self.ctx.context, buffer.buf)
    



# ctypedef object (*handle_buffer_cb)(const char* str, Py_ssize_t len) with gil

# cdef object handle_buffer(object , handle_buffer_cb cb):



cdef class Atom:
    cdef:
        JSAtom atom
        Context ctx

    @staticmethod
    cdef Atom new(Context ctx, JSAtom atom):
        cdef Atom self = Atom.__new__(Atom)
        self.ctx = ctx
        self.atom = atom
        return self

    @staticmethod
    cdef Atom from_python(Context ctx, object key):
        cdef Py_buffer view
        cdef JSAtom atom

        if isinstance(key, Value):
            atom = JS_ValueToAtom(ctx.context, key.value)

        elif isinstance(key, int):
            atom = JS_NewAtomUInt32(ctx.context, <uint32_t>key)

        else:
            if cyjs_get_buffer(key, &view) < 0:
                raise
            atom = JS_NewAtomLen(ctx.context, <const char*>view.buf, view.len)
            cyjs_release_buffer(&view)


        if atom == 0:
            ctx.raise_exception()
            raise
        
        return Atom.new(ctx, atom)
    
    # easiest way to allow JSAtom to be used as bytes is to use the buffer protocol
    # SEE: https://cython.readthedocs.io/en/latest/src/userguide/buffer.html#implementing-the-buffer-protocol

    def __getbuffer__(self, Py_buffer *buffer, int flags):
        cdef size_t size
        buffer.buf = <void*>JS_AtomToCStringLen(self.ctx.context, &size, self.atom)

        # SEE: https://docs.python.org/3/library/struct.html#format-characters
        buffer.format = 'b' # char
        buffer.internal = NULL
        buffer.itemsize = <Py_ssize_t>size # kinda don't know...
        buffer.len = <Py_ssize_t>size
        buffer.ndim = 0
        buffer.obj = self
        buffer.readonly = 0
        buffer.shape = NULL
        buffer.strides = NULL
        buffer.suboffsets = NULL
        
    def __releasebuffer__(self, Py_buffer *buffer):
        JS_FreeCString(self.ctx, buffer.buf)



cdef Atom to_atom(Context ctx, object obj):
    if isinstance(obj, Atom):
        return <Atom>obj
    return Atom.from_python(ctx, obj)

# wraps JSValue as Cython/Python object
cdef object to_py(Context ctx, JSValue val):
    cdef int tag = JS_VALUE_GET_TAG(value)
    cdef object return_value
    if tag == JS_TAG_INT:
        return_value = <object>val.u.int32
        JS_FreeValue(ctx.context, val)
        return return_value
    if tag == JS_TAG_BIG_INT:
        return BigInt.from_value(ctx, value)
    
    if tag == JS_TAG_BOOL:
        return_value = PyBool_FromLong(val.u.int32)
        JS_FreeValue(ctx.context, val)
        return return_value
    
    if tag == JS_TAG_NULL or tag == JS_TAG_UNDEFINED:
        JS_FreeValue(ctx.context, val)
        return None
    
    if tag == JS_TAG_EXCEPTION:
        ctx.raise_existing_exception(val)
        JS_FreeValue(ctx.context, val)
        raise
    
    if tag == JS_TAG_OBJECT or tag == JS_TAG_MODULE or tag == JS_TAG_SYMBOL:
        return Object.from_value(ctx, val)
    else:
        # Fallback and obtain as a buffer instead if needed...
        return Value.from_value(ctx, val)
        # JS_FreeValue(ctx.context, val)
        # raise TypeError("Unkown quickjs tag %i" % tag)
    


cpdef object from_json(Context ctx, object data):
    cdef Py_buffer view
    cdef object obj
    cdef JSValue v 
    if cyjs_get_buffer(data, &view) < 0:
        raise

    v = JS_ParseJSON(ctx.context, view.buf, view.len)
    cyjs_release_buffer(&view)
    
    # Handle exceptions here...
    return to_py(v)







# Private
cdef class NODEFAULT:
    pass


# ctypedef fused bigint_t:
#     int64_t
#     uint64_t



cdef class BigInt(Value):
    @staticmethod
    cdef BigInt from_value(Context ctx, JSValue value):
        cdef BigInt self = BigInt.__new__(BigInt)
        self.ctx = ctx
        self.value = value
        self.tag = JS_VALUE_GET_TAG(value)
        return self

    def __init__(self, Context ctx, object value) -> None:
        super().__init__()
        cdef JSValue v
        if value > LLONG_MAX:
            v = JS_NewBigUint64(ctx.context, value)
        else:
            v = JS_NewBigInt64(ctx.context, value)
        if ctx.handle_exception(v) < 0:
            raise
        self.value = value
    

    cpdef object to_int64(self):
        cdef int64_t i64 = 0
        
        if JS_ToBigInt64(self.ctx.context, &i64, self.value) < 0:
            raise TypeError("unable to convert BigInt to int64_t")
        return i64

    cpdef object to_uint64(self):
        cdef uint64_t i64 = 0
        
        if JS_ToBigUint64(self.ctx.context, &i64, self.value) < 0:
            raise TypeError("unable to convert BigInt to uint64_t")
        return i64
    

cdef class Object(Value):
    @classmethod
    cdef Object from_value(cls, Context ctx, JSValue value):
        cdef Object self = <Object>cls.__new__(cls)
        self.ctx = ctx
        self.value = value
        self.tag = JS_VALUE_GET_TAG(value)
        return self

    @classmethod
    cdef Object new(cls, Context ctx):
        cdef JSValue v = JS_NewObject(ctx.context)
        if ctx.handle_exception(v) < 0:
            raise
        return cls.from_value(ctx, v)

    cpdef bytes to_json(self):
        """
        Useful when debugging or handling unknown js to py conversions
        NOTE: for best results, using third party libraries like orjson 
        or msgspec is advised. 
        """
        cdef JSValue v = JS_JSONStringify(self.ctx.context, self.value, JS_UNDEFINED, JS_UNDEFINED)
        cdef size_t size
        cdef const char* data = JS_ToCStringLen(self.ctx.context, &size, self.value)
        cdef bytes ret = PyBytes_FromStringAndSize(data, size)
        JS_FreeCString(self.ctx.context, data)
        return ret






cdef class Function(Object):
    @staticmethod
    cdef Function from_value(Context ctx, JSValue value):
        cdef Function self = Function.__new__(Function)
        self.ctx = ctx
        self.value = value
        self.tag = JS_VALUE_GET_TAG(value)
        return self



    

    # A look at JS_GetPropertyStr can give us a glimpse about how to apporch this
    # cpdef object get(self, object key, object default = NODEFAULT):
    #     cdef Atom atom = to_atom(self.ctx, key)
    #     cdef Value val
    #     cdef JSValue js_val

    #     JS_GetProperty(self.ctx.context, )

cdef class CancelledError(Exception):
    """Promise was rejected"""

cdef class InvalidStateError(Exception):
    """Promise on inavlid state"""

# Made to resemble Concurrent.futures.Future and asyncio.Future

cdef class Promise(Object):
    """A Javascript Equivilent to asyncio.Future that has simillar functionality to one."""

    cdef:
        list _callbacks
        object _exception
        object _result

    @staticmethod
    cdef Promise from_value(Context ctx, JSValue value):
        cdef Promise self = Promise.__new__(Object)
        self.ctx = ctx
        self.value = value
        self.tag = JS_VALUE_GET_TAG(value)

        self._callbacks = []
        self._exception = None
        # _result can be None
        self._result = NODEFAULT
        return self

    cdef JSPromiseStateEnum c_state(self) except JS_PROMISE_NOT_A_PROMISE:
        cdef JSPromiseStateEnum state = JS_PromiseState(self.ctx.context)
        if state == JS_PROMISE_NOT_A_PROMISE:
            PyErr_SetObject(TypeError, f"{self.__class__.__name__!r} not a promise!")
            return JS_PROMISE_NOT_A_PROMISE
        return state
    
    cpdef object add_done_callback(self, object fn):
        """Attaches a callable callback when promise finishes or raises an exception"""
        if self.c_state() == JS_PROMISE_PENDING:
            self._callbacks.append(fn)
        else:
            fn(self)
    
    cdef object __get_result(self):
        if self._exception:
            try:
                raise self._exception
            finally:
                # Break a reference cycle with the exception in self._exception
                self = None
        else:
            return self._result

    cpdef object exception(self):
        cdef JSPromiseStateEnum state = self.c_state()
        if state == JS_PROMISE_REJECTED:
            raise CancelledError()
        elif state == JS_PROMISE_PENDING:
            raise InvalidStateError('Result is not ready.')
        return self._exception
    
    cpdef bint done(self):
        return JS_PromiseState(self.ctx.context) == JS_PROMISE_FULFILLED

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
        cdef JSPromiseStateEnum state = self.c_state()
        if state == JS_PROMISE_REJECTED:
            raise CancelledError()
        if state == JS_PROMISE_FULFILLED:
            if self._exception is not None:
                raise self._exception
            return to_py(self.ctx, JS_PromiseResult(self.ctx.context, self.value))
        else:
            raise InvalidStateError('Result is not ready.')

    # Does a single eventloop cycle to see if the promise is ready
    # if ready it returns True otherwise False, raises exception if one was raised
    cpdef object poll(self):
        cdef int ret
        cdef JSValue v
        if self.done():
            return True
        if JS_IsJobPending(self.ctx.runtime.rt):
            if JS_ExecutePendingJob(self.ctx.runtime.rt, &self.ctx.context) < 0:
                self.ctx.raise_exception()
                raise

        if self.done():
            # promise finished so lets see if that result was an exception or not
            v = JS_PromiseResult(self.ctx.context, self.value)
            if JS_IsException(v):
                self._exception = self.ctx.get_raised_exception()
            else:
                self._result = to_py(self.ctx, v)
            # Run all callbacks at this point in time...

            for cb in self._callbacks:
                cb(self)
            return True
        else:
            return False











 

    # def prop(self, object key):
    #     cdef Atom at = to_atom(self.ctx, key)

    #     JS_DefineProperty()
    





# From Python docs (This table was brought over as a helpful cheat sheet)
# 'b' signed char | int  | 1
# 'B' unsigned char | int | 1
# 'u' wchar_t | Unicode character | 2 (1)
# 'w' Py_UCS4 | Unicode character |	4 (2)
# 'h' signed short | int | 2
# 'H' unsigned short | int | 2
# 'i' signed int | int | 2
# 'I' unsigned int | int | 2
# 'l' signed long | int | 4
# 'L' unsigned long | int | 4
# 'q' signed long long | int | 8
# 'Q' unsigned long long | int | 8
# 'f' float | float | 4
# 'd' double | float | 8


# cdef Value from_array(Context ctx, array arr):
#     cdef char tc = arr.ob_descr.typecode

#     if tc == 'B':
#         JS_NewUint8ArrayCopy(ctx.context, arr.ob_descr.as_uchars, <size_t>arr.ob_size)
#     elif tc == 'b':
#         JS_NewArrayBuffer()




   
