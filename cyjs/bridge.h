


/* Msgspec utils are used here to cheat out on a few things */

/*
Copyright (c) 2021, Jim Crist-Harif
All rights reserved.

Redistribution and use in source and binary forcyares, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
  may be used to endorse or promote products derived from this software
  without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


*/

#ifndef __BRIDGE_H__
#define __BRIDGE_H__

#include <stdio.h> // FILE*
#include <inttypes.h> // PRId64
#include <stdbool.h>

#include "Python.h"
#include "quickjs.h"
#include "cutils.h" // Quickjs's cutils (This is needed) I will throw issue on their end if I can't access this.

#ifdef __cplusplus
extern "C" {
#endif



/* 
This mirrors cutils.h, this doesn't need changing because it's 
simply measuring a specific pointer so it's valid under our terms of use. 
However if you think this is a conern, feel free to throw me an issue about it. 
*/
static inline size_t py__malloc_usable_size(const void *ptr)
{
#if defined(__APPLE__)
    return malloc_size(ptr);
#elif defined(_WIN32)
    return _msize((void *)ptr);
#elif defined(__linux__) || defined(__ANDROID__) || defined(__CYGWIN__) || defined(__FreeBSD__) || defined(__GLIBC__)
    return malloc_usable_size((void *)ptr);
#else
    return 0;
#endif
}

/* these were easier to write in C than in Cython and came at the
benefit of being less costly to maintain. */

/* To prevent the GIL from causing problems the Raw verisons of 
python's memory allocators are used... */
static void *py_def_calloc(void *opaque, size_t count, size_t size)
{
    return PyMem_RawCalloc(count, size);
}

static void *py_def_malloc(void *opaque, size_t size)
{
    return PyMem_RawMalloc(size);
}

static void py_def_free(void *opaque, void *ptr)
{
    PyMem_RawFree(ptr);
}

static void *py_def_realloc(void *opaque, void *ptr, size_t size)
{
    return PyMem_RawRealloc(ptr, size);
}

static const JSMallocFunctions py_malloc_funcs = {
    py_def_calloc,
    py_def_malloc,
    py_def_free,
    py_def_realloc,
    py__malloc_usable_size,
};

/* Mainly it is just here for checking internal signals but 
this might be expanded upon and moved to cython after beta/first release 
*/
static int CYJS_SigInterruptHandler(JSRuntime* rt, void* op){
    return PyErr_CheckSignals();
}

static JSValue CYJS_ThrowException(JSContext* ctx, const char* msg){
    return JS_ThrowPlainError(ctx, msg);
}

/// @brief Creates a new JSRuntime using python memory instead of C's
/// Heap, for better performance by allowing mimalloc to be utlized 
/// but also enables collecting from python's own recycle bin.
/// @param opaque parent object (Normally this would be the class wrapper)
/// @return JSRuntime if all was successful otherwise this will show up as Null.
static JSRuntime* CYJS_NewRuntime(void* opaque){
    JSRuntime* rt = JS_NewRuntime2(&py_malloc_funcs, opaque);
    /* it's a bit faster to throw an exception here with only needing
    raise when runtime is NULL */

    if (rt == NULL)
        PyErr_NoMemory();
    
    /* There is a few reasons as to why we would want to try putting 
    the interrupt handle here for now and this is mainly to make sure that if or when a user hits CTRL+c 
    the program remebers to exit (Will move it to cython after all of the first tests succeed and the library has had it's first release) */
 
    /* the interrupt handler has a NULL Opaque for right now because we can ignore needing it. */
    JS_SetInterruptHandler(rt, CYJS_SigInterruptHandler, NULL);
    return rt;
}




/* It didn't feel pratical to bring this all to cython */
static void CYJS_InitalizeSettings(
    JSContext* ctx,
    bool base_objects,
    bool date,
    bool intrinsic_eval,
    bool regexp_compiler,
    bool regexp,
    bool json,
    bool proxy,
    bool map_set,
    bool typed_arrays,
    bool bigint,
    bool weak_ref,
    bool performance,
    bool dom_exception,
    bool promise
){
    if (base_objects)
        JS_AddIntrinsicBaseObjects(ctx);
    if (date) 
        JS_AddIntrinsicDate(ctx);
    if (intrinsic_eval)
        JS_AddIntrinsicEval(ctx);
    if (regexp)
        JS_AddIntrinsicRegExp(ctx);
    if (json)
        JS_AddIntrinsicJSON(ctx);
    if (proxy)
        JS_AddIntrinsicProxy(ctx);
    if (map_set)
        JS_AddIntrinsicMapSet(ctx);
    if (typed_arrays)
        JS_AddIntrinsicTypedArrays(ctx);
    if (promise)
        JS_AddIntrinsicPromise(ctx);
    if (bigint)
        JS_AddIntrinsicBigInt(ctx);
    if (weak_ref)
        JS_AddIntrinsicWeakRef(ctx);
    if (dom_exception)
        JS_AddIntrinsicDOMException(ctx);
    if (performance)
        JS_AddPerformance(ctx);

}


static PyObject* CYJS_FSConvert(PyObject* file){
    PyObject* filename_bytes = NULL;
    if (PyUnicode_FSConverter(file, &filename_bytes) < 0)
        return NULL;
    return filename_bytes;
}


static int CYJS_DumpMemoryUsage(JSRuntime* rt, PyObject* file){
    
    PyObject* filename_bytes = NULL;
    JSMemoryUsage mu;

    // Me being aggressive
    if (rt == NULL || file == NULL){
        PyErr_SetString(PyExc_TypeError, "(runtime & file) cannot be passed as NULL");
        return -1;
    }

    // Kinda stupid how cython doesn't make use of this function 
    // when it serves great importance with python's builtin open() function
    if (PyUnicode_FSConverter(file, &filename_bytes) < 0)
        return -1;

    // We need a file pointer.
    FILE* fp = fopen((const char*)PyBytes_AS_STRING(filename_bytes), "w");
    if (fp == NULL){
        PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, file);
        Py_CLEAR(filename_bytes);
        return -1;
    }
    JS_ComputeMemoryUsage(rt, &mu);
    JS_DumpMemoryUsage(fp, (const JSMemoryUsage*)(&mu), rt);
    fclose(fp);
    Py_CLEAR(filename_bytes);
    return 0;
}


#ifdef __GNUC__
#define CYJS_LIKELY(pred) __builtin_expect(!!(pred), 1)
#define CYJS_UNLIKELY(pred) __builtin_expect(!!(pred), 0)
#else
#define CYJS_LIKELY(pred) (pred)
#define CYJS_UNLIKELY(pred) (pred)
#endif

#ifdef __GNUC__
#define CYJS_INLINE __attribute__((always_inline)) inline
#define CYJS_NOINLINE __attribute__((noinline))
#elif defined(_MSC_VER)
#define CYJS_INLINE __forceinline
#define CYJS_NOINLINE __declspec(noinline)
#else
#define CYJS_INLINE inline
#define CYJS_NOINLINE
#endif

/* XXX: Optimized `PyUnicode_AsUTF8AndSize` for strs that we know have
 * a cached unicode representation. */
static inline const char *
unicode_str_and_size_nocheck(PyObject *str, Py_ssize_t *size) {
    if (CYJS_LIKELY(PyUnicode_IS_COMPACT_ASCII(str))) {
        *size = ((PyASCIIObject *)str)->length;
        return (char *)(((PyASCIIObject *)str) + 1);
    }
    *size = ((PyCompactUnicodeObject *)str)->utf8_length;
    return ((PyCompactUnicodeObject *)str)->utf8;
}

/* XXX: Optimized `PyUnicode_AsUTF8AndSize` */
static inline const char *
unicode_str_and_size(PyObject *str, Py_ssize_t *size) {
#ifndef Py_GIL_DISABLED
    const char *out = unicode_str_and_size_nocheck(str, size);
    if (CYJS_LIKELY(out != NULL)) return out;
#endif
    return PyUnicode_AsUTF8AndSize(str, size);
}

static CYJS_INLINE char *
ascii_get_buffer(PyObject *str) {
    return (char *)(((PyASCIIObject *)str) + 1);
}

/* Fill in view.buf & view.len from either a Unicode or buffer-compatible
 * object. */
static int
cyjs_get_buffer(PyObject *obj, Py_buffer *view) {
    if (CYJS_UNLIKELY(PyUnicode_CheckExact(obj))) {
        view->buf = (void *)unicode_str_and_size(obj, &(view->len));
        if (view->buf == NULL) return -1;
        Py_INCREF(obj);
        view->obj = obj;
        return 0;
    }
    return PyObject_GetBuffer(obj, view, PyBUF_CONTIG_RO);
}

static void
cyjs_release_buffer(Py_buffer *view) {
    if (CYJS_LIKELY(!PyUnicode_CheckExact(view->obj))) {
        PyBuffer_Release(view);
    }
    else {
        Py_CLEAR(view->obj);
    }
}




/// @brief Initalizes JSClassDef with help from a PyObject
/// @param obj The Python Object/Class or Cython C Extension object to intialize
/// @param cls The JSClass Definition
/// @param finalizer Optional Callback
/// @param gc_mark Optional Callback
/// @param call Optional Callback
// void CYJS_CreateJSClassDef(
//     PyObject* obj, 
//     JSClassDef* cls, 
//     JSClassFinalizer *finalizer,
//     JSClassGCMark* gc_mark,
//     JSClassCall* call,
// ){
//     /* XXX: Cython is not very capable of this but is perfectly acceptable in C... */
//     cls->class_name = Py_TYPE(obj)->tp_name;
//     cls->finalizer = finalizer;
//     cls->gc_mark = gc_mark;
//     cls->call = call;

// }


#ifdef __cplusplus
}
#endif

#endif // __BRIDGE_H__