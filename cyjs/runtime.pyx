from .quickjs cimport *
from .mem cimport MemoryUsage


cdef extern from "bridge.h":
    JSRuntime* CYJS_NewRuntime(void* opaque)
    # Needed because we need full support with what __bultins__.open(...) does...
    int CYJS_DumpMemoryUsage(JSRuntime* rt, object file) except -1


cdef class Runtime:
    """
    Represents a JavaScript runtime corresponding to an
    object heap. Several runtimes can exist at the same time but they
    cannot exchange objects. Inside a given runtime, no multi-threading is
    supported.
    """

    # will be using runtimes through the entire code a lot
    # so a simple name will make all the differences.
    
    # TODO: (Vizonex): Exception handler system for throwing
    # exceptions with a default version also when in a state 
    # of limbo (example: on a noexcept callback frame)
    # All we would have to do is after certain functions are called off
    # check and see if we got an exception from one of our containers and call it off...
    # object exc_handler # handles exceptions

    def __init__(self) -> None:
        # Will set the parent immediately as a preformance optimization
        cdef JSRuntime* rt = CYJS_NewRuntime(<void*>self)
        # We're going to assume it's a memoryerror
        # since the code fails when the runtime fails 
        # to allocate memory. There's no other good reasons for failure.
        if rt == NULL:
            raise MemoryError()
        self.rt = rt

    cpdef void set_memory_limit(self, size_t limit):
        JS_SetMemoryLimit(self.rt, limit)

    cpdef void set_max_stack_size(self, size_t max_stack_size):
        JS_SetMaxStackSize(self.rt, max_stack_size)

    # Properties
    @property
    def dump_flags(self):
        return JS_GetDumpFlags(self.rt)

    @dump_flags.setter
    def dump_flags(self, uint64_t flags):
        JS_SetDumpFlags(self.rt, flags)

    @property
    def gc_threshold(self):
        return JS_GetGCThreshold(self.rt)

    @gc_threshold.setter
    def gc_threshold(self, size_t gc_threshold):
        JS_SetGCThreshold(self.rt, gc_threshold)


    cpdef MemoryUsage compute_memory_usage(self):
        """C Equivilent to JS_ComputeMemoryUsage(...) but returns a 
        MemoryUsage cython class instead of a struct."""
        cdef JSMemoryUsage mu
        JS_ComputeMemoryUsage(self.rt, &mu)
        return MemoryUsage.new(&mu)


    cpdef void update_statck_top(self):
        JS_UpdateStackTop(self.rt)


    cpdef Context context(self):
        """creates a new Javascript context"""
        cdef JSContext* ctx = JS_NewContext(self.rt)
        if ctx == NULL:
            # TODO: is this an accurate error?
            raise MemoryError
        
        # send self so that Context doesn't dealloc or crash
        return Context.new(ctx, self)

    

    def __dealloc__(self):
        if self.rt != NULL:
            JS_FreeRuntime(self.rt)
    