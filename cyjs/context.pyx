from .quickjs cimport *
from .value cimport Value
from libc.string cimport strstr
from cpython.exc cimport PyErr_Clear
from cpython.object cimport PyObject

cdef extern from "bridge.h":
    int cyjs_get_buffer(object, Py_buffer*) except -1
    void cyjs_release_buffer(Py_buffer* view)
    

cdef extern from "Python.h":
    """
/* XXX: Cython gets into trouble with these formats */

#define CYJS_ErrFormat(exc, desc, stack) \\
    PyErr_Format(exc, "%s\\n%s", desc, (stack ? stack: ""))
    """
    PyObject* CYJS_ErrFormat(object exc, const char* desc, const char* stack)

cdef extern from "bridge.h":
    int cyjs_get_buffer(object obj, Py_buffer* view) except -1
    void cyjs_release_buffer(Py_buffer* view)
    object CYJS_FSConvert(object file)



JS_EVAL_TYPE_GLOBAL = (0 << 0) # global code (default) */
JS_EVAL_TYPE_MODULE = (1 << 0) # module code */
JS_EVAL_TYPE_DIRECT = (2 << 0) # direct call (internal use) */
JS_EVAL_TYPE_INDIRECT = (3 << 0) # indirect call (internal use) */
JS_EVAL_TYPE_MASK  =  (3 << 0)
JS_EVAL_FLAG_STRICT = (1 << 3) # force 'strict' mode */
JS_EVAL_FLAG_UNUSED = (1 << 4) # unused */
# # compile but do not run. The result is an object with a
#    JS_TAG_FUNCTION_BYTECODE or JS_TAG_MODULE tag. It can be executed
#    with JS_EvalFunction(). */
JS_EVAL_FLAG_COMPILE_ONLY = (1 << 5)
# # don't include the stack frames before this eval in the Error() backtraces */
JS_EVAL_FLAG_BACKTRACE_BARRIER = (1 << 6)
# # allow top-level await in normal script. JS_Eval() returns a
#    promise. Only allowed with JS_EVAL_TYPE_GLOBAL */
JS_EVAL_FLAG_ASYNC = (1 << 7)


cdef class JSError(Exception):
    pass

cdef class Context:
    """
    Represents a JavaScript context (or Realm). Each
    JSContext has its own global objects and system objects. There can be
    several JSContexts per JSRuntime and they can share objects, similar
    to frames of the same origin sharing JavaScript objects in a
    web browser.
    """
    
    @staticmethod
    cdef Context new(JSContext* context, Runtime runtime):
        cdef Context self = Context.__new__(Context)
        self.context = context
        JS_SetContextOpaque(context, <void*>self)
        self.runtime = runtime
        return self

    def __dealloc__(self):
        if self.context != NULL:
            JS_FreeContext(self.context)
    
    # js_ funcs are inlined versions of the Context API used for
    # Cython interactions instead of python ones...

    cdef void raise_exception(self):
        self.raise_existing_exception(JS_GetException(self.context))


    cdef void raise_existing_exception(self, JSValue exception):
        cdef JSValue stack
        cdef const char *cstring = JS_ToCString(self.context, exception)
        cdef const char* stack_cstring = NULL
        if (not JS_IsNull(exception) and not JS_IsUndefined(exception)):
            stack = JS_GetPropertyStr(self.context, exception, "stack");
            if not JS_IsException(stack):
                stack_cstring = JS_ToCString(self.context, stack)
                JS_FreeValue(self.context, stack)

        if cstring != NULL:
            if strstr(cstring, "stack overflow") != NULL:
                CYJS_ErrFormat(OverflowError, cstring, stack_cstring)
            else:
                CYJS_ErrFormat(JSError, cstring, stack_cstring)

        JS_FreeCString(self.context, cstring)
        JS_FreeCString(self.context, stack_cstring)
        JS_FreeValue(self.context, exception)
    
    cdef object get_raised_exception(self, JSValue exception):
        cdef object exc = None
        try:
            self.raise_existing_exception(exception)
            raise
        except Exception as exc:
            return exc

    
    cdef JSValue js_eval(
        self, 
        const char *input, 
        size_t input_len, 
        const char *filename, 
        int eval_flags
    ):
        return JS_Eval(self.context, input, input_len, filename, eval_flags)




    
    
    # Based off the rust implementation rquickjs titled handle_exception
    cdef int handle_exception(self, JSValue value) except -1:
        if JS_VALUE_GET_TAG(value) == JS_TAG_EXCEPTION:
            self.raise_existing_exception(value)
            return -1
        return 0

    

    