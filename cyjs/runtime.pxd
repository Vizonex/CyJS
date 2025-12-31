
from .context cimport Context
from .mem cimport MemoryUsage
from .quickjs cimport *



cdef class Runtime:
    """
    Represents a JavaScript runtime corresponding to an
    object heap. Several runtimes can exist at the same time but they
    cannot exchange objects. Inside a given runtime, no multi-threading is
    supported.
    """

    # will be using runtimes through the entire code a lot
    # so a simple name will make all the difference.
    cdef:
        JSRuntime* rt


    cpdef void set_memory_limit(self, size_t limit)
    cpdef void set_max_stack_size(self, size_t max_stack_size)
    cpdef MemoryUsage compute_memory_usage(self)
    cpdef void update_statck_top(self)
    cpdef Context context(self)
    

