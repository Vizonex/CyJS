from libc.stdint cimport int32_t
from .quickjs cimport JSValue
from .context cimport Context


cdef class Value:
    """
    Represents a JavaScript value which can be a primitive type 
    or an object.
    """

    cdef: 
        JSValue value
        # having the python wrapper's parent can help prevent GC from stealing the object
        Context ctx
        readonly int32_t tag # allow python to read this as an optimization
    
    @staticmethod
    cdef Value from_value(Context ctx, JSValue value)
    
