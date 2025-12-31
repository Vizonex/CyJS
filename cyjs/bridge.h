


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

/// @brief Creates a new JSRuntime using python memory instead of C's
/// Heap, for better performance by allowing mimalloc to be utlized 
/// but also enables collecting from python's own recycle bin.
/// @param opaque parent object (Normally this would be the class wrapper)
/// @return JSRuntime if all was successful otherwise this will show up as Null.
static JSRuntime* CYJS_NewRuntime(void* opaque){
    return JS_NewRuntime2(&py_malloc_funcs, opaque);
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


#ifdef __cplusplus
}
#endif

#endif // __BRIDGE_H__