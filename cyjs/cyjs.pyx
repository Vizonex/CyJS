cimport cython
from .quickjs cimport JS_GetVersion
from .runtime cimport Runtime
from .context cimport Context
from cpython.unicode cimport PyUnicode_FromString

cdef extern from "Python.h":
    # Gets around a few problems with non restorable parts
    void PyErr_SetRaisedException(object exc)
    object PyObject_CallOneArg(object func, object arg)


cpdef str quickjs_ng_version():
    return PyUnicode_FromString(JS_GetVersion())





# Reobtains Runtime assuming runtime it exists
# cdef Runtime runtime_from_ptr(JSRuntime* runtime) noexcept:
#     return <Runtime>JS_GetRuntimeOpaque(runtime)

# # Holds object's runtime as a Handle until clearable...
# @cython.final
# cdef class RuntimeFinalizer:
#     cdef:
#         object func # Callable[[Runtime], None]
#         # Prevents gc and allows for a faster callback
#         Runtime rt
    
#     def __cinit__(self, object func, Runtime rt):
#         if not callable(func):
#             raise TypeError("a runtime finalizer must be callable")
#         self.func = func
#         self.rt = rt
    
#     cdef void call(self):
#         return self.func(self.rt)

# cdef void on_runtime_finalizer(JSRuntime* rt, void* finalizer) noexcept:
#     cdef RuntimeFinalizer fn = <RuntimeFinalizer>finalizer
#     fn.call()


# cdef class ExceptionHandler:
#     """Made for carrying exceptions and throwing them later upon being discovered"""
#     cdef:
#         object handler
#         bint has_exception
    






