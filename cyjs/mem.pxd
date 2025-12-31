from libc.stdint cimport int64_t       
cimport cython
from .quickjs cimport JSMemoryUsage

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

