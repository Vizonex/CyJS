# cython: language_level = 3

cimport cython
from .quickjs cimport JSMemoryUsage

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
