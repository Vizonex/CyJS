# cython: freethreading_compatible = True

cimport cython
from libc.stdint cimport int64_t

from .quickjs cimport *


cdef extern from "bridge.h":
    JSRuntime* CYJS_NewRuntime(void* opaque)
    # Needed because we need full support with what __bultins__.open(...) does...
    int CYJS_DumpMemoryUsage(JSRuntime* rt, object file) except -1
    
    object CYJS_FSConvert(object file)

    int cyjs_get_buffer(object, Py_buffer*) except -1
    void cyjs_release_buffer(Py_buffer* view)

    JSValue CYJS_ThrowException(JSContext* ctx, const char* msg)
    void CYJS_CreateJSClassDef(
        object obj,
        JSClassDef* cls,
        JSClassFinalizer *finalizer,
        JSClassGCMark* gc_mark,
        JSClassCall* call,
        JSClassExoticMethods* exotic
    )
    void CYJS_InitalizeSettings(
        JSContext* ctx,
        bint base_objects,
        bint date,
        bint intrinsic_eval,
        bint regexp_compiler,
        bint regexp,
        bint json,
        bint proxy,
        bint map_set,
        bint typed_arrays,
        bint bigint,
        bint weak_ref,
        bint performance,
        bint dom_exception,
        bint promise
    )

cdef class JSError(Exception):
    @staticmethod
    cdef JSError new(JSContext* ctx, JSValue value)



@cython.final
cdef class MemoryUsage:
    cdef:
        readonly int64_t malloc_size
        readonly int64_t malloc_limit
        readonly int64_t memory_used_size
        readonly int64_t malloc_count
        readonly int64_t memory_used_count
        readonly int64_t atom_count
        readonly int64_t atom_size
        readonly int64_t str_count
        readonly int64_t str_size
        readonly int64_t obj_count
        readonly int64_t obj_size
        readonly int64_t prop_count
        readonly int64_t prop_size
        readonly int64_t shape_count
        readonly int64_t shape_size
        readonly int64_t js_func_count
        readonly int64_t js_func_size
        readonly int64_t js_func_code_size
        readonly int64_t js_func_pc2line_count
        readonly int64_t array_count
        readonly int64_t fast_array_count
        readonly int64_t fast_array_elements
        readonly int64_t binary_object_count
        readonly int64_t binary_object_size

    @staticmethod
    cdef MemoryUsage new(const JSMemoryUsage *ptr)



# void promise_hook_cb(JSContext *ctx, JSPromiseHookType type,
#     JSValue promise, JSValue parent_promise, void *opaque):

# Used for hooking a promise callback without triggering a deref
# This class is not exactly public nor should it be imported.
@cython.internal
cdef class PromiseHook:
    cdef:
        object func
        Runtime rt

    @staticmethod
    cdef PromiseHook new(Runtime rt, object func)

    cdef void hook(self, JSContext *context, JSPromiseHookType type,
        JSValue promise, JSValue parent_promise) noexcept

        


    

cdef class Runtime:
    """
    Represents a JavaScript runtime corresponding to an
    object heap. Several runtimes can exist at the same time but they
    cannot exchange objects. Inside a given runtime, no multi-threading is
    supported.
    """
    cdef:
        JSRuntime* rt
        PromiseHook promise_hook
        bint has_promise_hook
        # # NOTE: This should not utilize a fully public name and 
        # # should be able to be named 
        # # something sneaky and discrete to evade bot detection if 
        # # cyjs is to be used as a Javascript solver. (If done correctly)
        # JSClassDef py_function_class_def
        # JSClassID py_function_id

    


    cpdef MemoryUsage compute_memory_usage(self)
    cpdef object dump_memory_usage(self, object file)

    cpdef object execute_pending_job(self) # -> Context | None

    cpdef bint is_job_pending(self)

    cdef JSContext* new_context(self) except NULL

    cpdef void run_gc(self)

    cpdef void set_memory_limit(self, size_t limit)
    cpdef void set_max_stack_size(self, size_t max_stack_size)
    cpdef void update_statck_top(self)

    cpdef object set_promise_hook(self, object func)



cdef class Object:
    cdef:
        readonly Context context
        readonly int32_t tag
        JSValue value
        JSContext* ctx


    cdef void init(self, Context ctx, JSValue value)
    cpdef bytes to_json(self)


cdef class JSFunction:
    """Used for acting as a bridge between Javascript and Python
    it is meant to be used as an access-point for Javascript (ECMA) to be called upon
    through python. It's not subclassed to Object however due to it's own nature
    but if needed can be accessed from the object property"""
    cdef:
        # access to python Quickjs-ng Context
        readonly Context context
        JSContext* ctx # quick access to C JSContext
        JSValue value
        object func

    @staticmethod
    cdef JSFunction new(Context context, object func)
    cdef JSValue call_js(self, JSContext *ctx, JSValue this_val, int argc, JSValue *argv, int magic) noexcept
    

cdef class Context:
    cdef:
        # public runtime for python access to value (can't be deleted)
        readonly Runtime runtime
        JSRuntime* rt
        JSContext* ctx
        # incase a hook of some kind with a void happens to throw an exception we can capture it.
        object _cb_exception
    

    # NOTE: I'm Putting type ignores here because
    # C function "get_exception" is implemented in pxd definition of C class "Context" without the "inline" qualifier
    # is incorrect. 
    # inlines are in fact correct even though cyright says otherwise. 

    cdef inline bint has_exception(self): # type: ignore
        return JS_HasException(self.ctx)

    cdef inline JSValue get_exception(self): # type: ignore
        return JS_GetException(self.ctx)

    cdef object raise_exception(self)
    cdef object ceval(
        self, 
        object code, 
        object filename =*,
        bint module =*, 
        bint strict =*,
        bint backtrace_barrier =*,
        bint promise =*
    )

    cpdef object eval(
        self, 
        object code, 
        object filename =*,
        bint strict =*,
        bint backtrace_barrier =*,
        bint promise =*
    )

    cpdef object eval_module(
        self, 
        object code, 
        object filename =*,
        bint strict =*,
        bint backtrace_barrier =*,
        bint promise =*
    )

    cpdef JSFunction add_function(
        self, 
        object func, 
        object name =*, 
        int count=*,
        int magic =* 
    )

    # For now it will be represented as an Object
    # but in the future it can be represented as a 
    # function the goal of new_function is to call it from
    # ecma rather than from python itself (should be obvious as to why)
    # cpdef Object new_function(self, object func, object name=*)

