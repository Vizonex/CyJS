from .quickjs cimport *

from .runtime cimport Runtime


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
    cdef:
        JSContext* context
        # prevent deallocating if context if present, 
        # allow python access to runtime as lazy access but disable replacing it.
        readonly Runtime runtime
    
    @staticmethod
    cdef Context new(JSContext* context, Runtime runtime)


    cdef void raise_exception(self)
    cdef void raise_existing_exception(self, JSValue exception)

    # Inspired by rquickjs
    cdef int handle_exception(self, JSValue value) except -1
    
    # Converts JSValue to an exception type and then returns it
    # with errors cleared. 
    cdef object get_raised_exception(self, JSValue exception)

 
    # These can be accessed from other external projects so I've fully exposed them under the JS Prefix...
    # cdef inline JSValue js_eval(
    #     self, 
    #     const char *input, 
    #     size_t input_len, 
    #     const char *filename, 
    #     int eval_flags
    # ):
    #     return JS_Eval(self.context, input, input_len, filename, eval_flags)
    
    # cdef inline JSValue js_eval2(
    #     self, 
    #     const char *input, 
    #     size_t input_len,
    #     JSEvalOptions *options
    # ):
    #     return JS_Eval2(self.context, input, input_len, options)

    #     # JS_IsInstanceOf
    # cdef inline JSValue js_eval_this(
    #     self, 
    #     JSValue this_obj,
    #     const char *input, 
    #     size_t input_len,
    #     const char *filename, 
    #     int eval_flags
    # ):
    #     return JS_EvalThis(
    #         self.context,
    #         input, 
    #         input_len, 
    #         filename, 
    #         eval_flags
    #     )

    # cdef inline JSValue js_eval_this_2(
    #     self, 
    #     JSValue this_obj, 
    #     const char *input, 
    #     size_t input_len, 
    #     JSEvalOptions *options
    # ):
    #     return JS_EvalThis2(
    #         self.context,
    #         this_obj,
    #         input,
    #         input_len,
    #         options
    #     )

    # cdef JSValue js_get_global_object(self):
    #     return JS_GetGlobalObject(self.context)

    # cdef inline int js_is_instance_of(
    #     self,
    #     JSValue val, 
    #     JSValue obj
    # ):
    #     return JS_IsInstanceOf(
    #         self.context, val, obj
    #     )

    # TODO: JS Properties and class objects
    # cdef inline int js_define_property(
    #     self, JSValue this_obj, JSAtom prop, JSValue val, JSValue getter, JSValue setter, int flags
    # ):



    
    