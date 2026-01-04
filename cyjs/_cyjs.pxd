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




cdef class Runtime:
    """
    Represents a JavaScript runtime corresponding to an
    object heap. Several runtimes can exist at the same time but they
    cannot exchange objects. Inside a given runtime, no multi-threading is
    supported.
    """
    cdef:
        JSRuntime* rt
        # NOTE: This should not utilize a fully public name and 
        # should be able to be named 
        # something sneaky and discrete to evade bot detection if 
        # cyjs is to be used as a Javascript solver. (If done correctly)
        JSClassDef py_function_class_def
        JSClassID py_function_id



    cpdef MemoryUsage compute_memory_usage(self)
    cpdef object dump_memory_usage(self, object file)

    cpdef object execute_pending_job(self) # -> Context | None

    cpdef bint is_job_pending(self)

    cdef JSContext* new_context(self) except NULL

    cpdef void run_gc(self)

    cpdef void set_memory_limit(self, size_t limit)
    cpdef void set_max_stack_size(self, size_t max_stack_size)
    cpdef void update_statck_top(self)




cdef class Object:
    cdef:
        readonly Context context
        JSValue value
        JSContext* ctx

    cdef void init(self, Context ctx, JSValue value)
    cpdef bytes to_json(self)

# # Maybe planned so that some stuff can be easily shortcutted out or removed
# # which may result in less crashing...
# cdef class JSFunction:
#     cdef:
#         object func
#         readonly Context context
#         JSValue value
#         JSContext* ctx
    
#     @staticmethod
#     cdef JSFunction new(
#         Context ctx,
#         JSValue value,
#         object func
#     )



cdef class Context:
    cdef:
        # public runtime for python access to value (can't be deleted)
        readonly Runtime runtime
        JSRuntime* rt
        JSContext* ctx
        
   
    cdef bint has_exception(self)
    cdef JSValue get_exception(self)
    cdef object raise_exception(self)
    cpdef object eval(
        self, 
        object code, 
        object filename =*,
        bint module =*, 
        bint strict =*,
        bint backtrace_barrier =*,
        bint promise =*
    )

    # For now it will be represented as an Object
    # but in the future it can be represented as a 
    # function the goal of new_function is to call it from
    # ecma rather than from python itself (should be obvious as to why)
    # cpdef Object new_function(self, object func, object name=*)





