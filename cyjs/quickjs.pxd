from libc.stdint cimport int16_t as int16_t
from libc.stdint cimport int32_t as int32_t
from libc.stdint cimport int64_t as int64_t
from libc.stdint cimport uint16_t as uint16_t
from libc.stdint cimport uint32_t as uint32_t
from libc.stdint cimport uint64_t as uint64_t
from libc.stdint cimport uint8_t as uint8_t
from libc.stdint cimport uintptr_t as uintptr_t
from libc.stdio cimport FILE as FILE

cdef extern from "quickjs/quickjs.h" nogil:
    enum pxdgen_anon_toplevel_0:
        JS_TAG_FIRST = -9
        JS_TAG_BIG_INT = -9
        JS_TAG_SYMBOL = -8
        JS_TAG_STRING = -7
        JS_TAG_MODULE = -3
        JS_TAG_FUNCTION_BYTECODE = -2
        JS_TAG_OBJECT = -1
        JS_TAG_INT = 0
        JS_TAG_BOOL = 1
        JS_TAG_NULL = 2
        JS_TAG_UNDEFINED = 3
        JS_TAG_UNINITIALIZED = 4
        JS_TAG_CATCH_OFFSET = 5
        JS_TAG_EXCEPTION = 6
        JS_TAG_SHORT_BIG_INT = 7
        JS_TAG_FLOAT64 = 8
    struct JSClass:
        pass
    struct JSModuleDef:
        pass
    struct JSGCObjectHeader:
        pass
    struct JSContext:
        pass
    struct JSObject:
        pass
    struct JSRuntime:
        pass
    ctypedef JSRuntime JSRuntime
    ctypedef JSContext JSContext
    ctypedef JSObject JSObject
    ctypedef JSClass JSClass
    ctypedef uint32_t JSClassID
    ctypedef uint32_t JSAtom
    union JSValueUnion:
        int32_t int32
        double float64
        void* ptr
        int32_t short_big_int
    ctypedef JSValueUnion JSValueUnion
    struct JSValue:
        JSValueUnion u
        int64_t tag
    ctypedef JSValue JSValue
    JSValue __JS_NewFloat64(double)
    JSValue __JS_NewShortBigInt(JSContext*, int64_t)
    bint JS_VALUE_IS_NAN(JSValue)
    ctypedef JSValue (*JSCFunction)(JSContext*, JSValue, int, JSValue*) noexcept with gil
    ctypedef JSValue (*JSCFunctionMagic)(JSContext*, JSValue, int, JSValue*, int) noexcept with gil
    ctypedef JSValue (*JSCFunctionData)(JSContext*, JSValue, int, JSValue*, int, JSValue*) noexcept with gil
    ctypedef JSValue (*JSCClosure)(JSContext*, JSValue, int, JSValue*, int, void*) noexcept with gil
    struct JSMallocFunctions:
        void* (*js_calloc)(void*, size_t, size_t)
        void* (*js_malloc)(void*, size_t)
        void (*js_free)(void*, void*)
        void* (*js_realloc)(void*, void*, size_t)
        size_t (*js_malloc_usable_size)(const void*)
    ctypedef JSMallocFunctions JSMallocFunctions
    ctypedef void (*JSRuntimeFinalizer)(JSRuntime*, void*) with gil
    ctypedef JSGCObjectHeader JSGCObjectHeader
    JSRuntime* JS_NewRuntime()
    void JS_SetRuntimeInfo(JSRuntime*, const char*)
    void JS_SetMemoryLimit(JSRuntime*, size_t)
    void JS_SetDumpFlags(JSRuntime*, uint64_t)
    uint64_t JS_GetDumpFlags(JSRuntime*)
    size_t JS_GetGCThreshold(JSRuntime*)
    void JS_SetGCThreshold(JSRuntime*, size_t)
    void JS_SetMaxStackSize(JSRuntime*, size_t)
    void JS_UpdateStackTop(JSRuntime*)
    JSRuntime* JS_NewRuntime2(JSMallocFunctions*, void*)
    void JS_FreeRuntime(JSRuntime*)
    void* JS_GetRuntimeOpaque(JSRuntime*)
    void JS_SetRuntimeOpaque(JSRuntime*, void*)
    int JS_AddRuntimeFinalizer(JSRuntime*, JSRuntimeFinalizer*, void*)
    ctypedef void JS_MarkFunc(JSRuntime*, JSGCObjectHeader*)
    void JS_MarkValue(JSRuntime*, JSValue, JS_MarkFunc*)
    void JS_RunGC(JSRuntime*)
    bint JS_IsLiveObject(JSRuntime*, JSValue)
    JSContext* JS_NewContext(JSRuntime*)
    void JS_FreeContext(JSContext*)
    JSContext* JS_DupContext(JSContext*)
    void* JS_GetContextOpaque(JSContext*)
    void JS_SetContextOpaque(JSContext*, void*)
    JSRuntime* JS_GetRuntime(JSContext*)
    void JS_SetClassProto(JSContext*, JSClassID, JSValue)
    JSValue JS_GetClassProto(JSContext*, JSClassID)
    JSValue JS_GetFunctionProto(JSContext*)
    JSContext* JS_NewContextRaw(JSRuntime*)
    void JS_AddIntrinsicBaseObjects(JSContext*)
    void JS_AddIntrinsicDate(JSContext*)
    void JS_AddIntrinsicEval(JSContext*)
    void JS_AddIntrinsicRegExpCompiler(JSContext*)
    void JS_AddIntrinsicRegExp(JSContext*)
    void JS_AddIntrinsicJSON(JSContext*)
    void JS_AddIntrinsicProxy(JSContext*)
    void JS_AddIntrinsicMapSet(JSContext*)
    void JS_AddIntrinsicTypedArrays(JSContext*)
    void JS_AddIntrinsicPromise(JSContext*)
    void JS_AddIntrinsicBigInt(JSContext*)
    void JS_AddIntrinsicWeakRef(JSContext*)
    void JS_AddPerformance(JSContext*)
    void JS_AddIntrinsicDOMException(JSContext*)
    int JS_IsEqual(JSContext*, JSValue, JSValue)
    bint JS_IsStrictEqual(JSContext*, JSValue, JSValue)
    bint JS_IsSameValue(JSContext*, JSValue, JSValue)
    bint JS_IsSameValueZero(JSContext*, JSValue, JSValue)
    JSValue js_string_codePointRange(JSContext*, JSValue, int, JSValue*)
    void* js_calloc_rt(JSRuntime*, size_t, size_t)
    void* js_malloc_rt(JSRuntime*, size_t)
    void js_free_rt(JSRuntime*, void*)
    void* js_realloc_rt(JSRuntime*, void*, size_t)
    size_t js_malloc_usable_size_rt(JSRuntime*, const void*)
    void* js_mallocz_rt(JSRuntime*, size_t)
    void* js_calloc(JSContext*, size_t, size_t)
    void* js_malloc(JSContext*, size_t)
    void js_free(JSContext*, void*)
    void* js_realloc(JSContext*, void*, size_t)
    size_t js_malloc_usable_size(JSContext*, const void*)
    void* js_realloc2(JSContext*, void*, size_t, size_t*)
    void* js_mallocz(JSContext*, size_t)
    char* js_strdup(JSContext*, const char*)
    char* js_strndup(JSContext*, const char*, size_t)
    struct JSMemoryUsage:
        int64_t malloc_size
        int64_t malloc_limit
        int64_t memory_used_size
        int64_t malloc_count
        int64_t memory_used_count
        int64_t atom_count
        int64_t atom_size
        int64_t str_count
        int64_t str_size
        int64_t obj_count
        int64_t obj_size
        int64_t prop_count
        int64_t prop_size
        int64_t shape_count
        int64_t shape_size
        int64_t js_func_count
        int64_t js_func_size
        int64_t js_func_code_size
        int64_t js_func_pc2line_count
        int64_t js_func_pc2line_size
        int64_t c_func_count
        int64_t array_count
        int64_t fast_array_count
        int64_t fast_array_elements
        int64_t binary_object_count
        int64_t binary_object_size
    ctypedef JSMemoryUsage JSMemoryUsage
    void JS_ComputeMemoryUsage(JSRuntime*, JSMemoryUsage*)
    void JS_DumpMemoryUsage(FILE*, JSMemoryUsage*, JSRuntime*)
    
    # Pull request for this one is pending: SEE: https://github.com/quickjs-ng/quickjs/pull/1284
    # ctypedef int (*JS_MemoryUsageCB)(void* opaque, const char* data, size_t data_len) noexcept with gil
    # int JS_WriteMemoryUsage(JS_MemoryUsageCB cb, const JSMemoryUsage *s, JSRuntime *rt, void* opaque)
    JSAtom JS_NewAtomLen(JSContext*, const char*, size_t)
    JSAtom JS_NewAtom(JSContext*, const char*)
    JSAtom JS_NewAtomUInt32(JSContext*, uint32_t)
    JSAtom JS_DupAtom(JSContext*, JSAtom)
    JSAtom JS_DupAtomRT(JSRuntime*, JSAtom)
    void JS_FreeAtom(JSContext*, JSAtom)
    void JS_FreeAtomRT(JSRuntime*, JSAtom)
    JSValue JS_AtomToValue(JSContext*, JSAtom)
    JSValue JS_AtomToString(JSContext*, JSAtom)
    const char* JS_AtomToCStringLen(JSContext*, size_t*, JSAtom)
    const char* JS_AtomToCString(JSContext*, JSAtom)
    JSAtom JS_ValueToAtom(JSContext*, JSValue)
    struct JSPropertyEnum:
        bint is_enumerable
        JSAtom atom
    ctypedef JSPropertyEnum JSPropertyEnum
    struct JSPropertyDescriptor:
        int flags
        JSValue value
        JSValue getter
        JSValue setter
    ctypedef JSPropertyDescriptor JSPropertyDescriptor
    struct JSClassExoticMethods:
        int (*get_own_property)(JSContext*, JSPropertyDescriptor*, JSValue, JSAtom)
        int (*get_own_property_names)(JSContext*, JSPropertyEnum**, uint32_t*, JSValue)
        int (*delete_property)(JSContext*, JSValue, JSAtom)
        int (*define_own_property)(JSContext*, JSValue, JSAtom, JSValue, JSValue, JSValue, int)
        int (*has_property)(JSContext*, JSValue, JSAtom)
        JSValue (*get_property)(JSContext*, JSValue, JSAtom, JSValue)
        int (*set_property)(JSContext*, JSValue, JSAtom, JSValue, JSValue, int)
    ctypedef JSClassExoticMethods JSClassExoticMethods
    ctypedef void JSClassFinalizer(JSRuntime*, JSValue)
    ctypedef void JSClassGCMark(JSRuntime*, JSValue, JS_MarkFunc*)
    ctypedef JSValue JSClassCall(JSContext*, JSValue, JSValue, int, JSValue*, int)
    struct JSClassDef:
        const char* class_name
        JSClassFinalizer* finalizer
        JSClassGCMark* gc_mark
        JSClassCall* call
        JSClassExoticMethods* exotic
    ctypedef JSClassDef JSClassDef
    struct JSEvalOptions:
        int version
        int eval_flags
        const char* filename
        int line_num
    ctypedef JSEvalOptions JSEvalOptions
    JSClassID JS_NewClassID(JSRuntime*, JSClassID*)
    JSClassID JS_GetClassID(JSValue)
    int JS_NewClass(JSRuntime*, JSClassID, JSClassDef*)
    bint JS_IsRegisteredClass(JSRuntime*, JSClassID)
    JSAtom JS_GetClassName(JSRuntime*, JSClassID)
    JSValue JS_NewBool(JSContext*, bint)
    JSValue JS_NewInt32(JSContext*, int32_t)
    JSValue JS_NewFloat64(JSContext*, double)
    JSValue JS_NewCatchOffset(JSContext*, int32_t)
    JSValue JS_NewInt64(JSContext*, int64_t)
    JSValue JS_NewUint32(JSContext*, uint32_t)
    JSValue JS_NewNumber(JSContext*, double)
    JSValue JS_NewBigInt64(JSContext*, int64_t)
    JSValue JS_NewBigUint64(JSContext*, uint64_t)
    bint JS_IsNumber(JSValue)
    bint JS_IsBigInt(JSValue)
    bint JS_IsBool(JSValue)
    bint JS_IsNull(JSValue)
    bint JS_IsUndefined(JSValue)
    bint JS_IsException(JSValue)
    bint JS_IsUninitialized(JSValue)
    bint JS_IsString(JSValue)
    bint JS_IsSymbol(JSValue)
    bint JS_IsObject(JSValue)
    bint JS_IsModule(JSValue)
    JSValue JS_Throw(JSContext*, JSValue)
    JSValue JS_GetException(JSContext*)
    bint JS_HasException(JSContext*)
    bint JS_IsError(JSValue)
    bint JS_IsUncatchableError(JSValue)
    void JS_SetUncatchableError(JSContext*, JSValue)
    void JS_ClearUncatchableError(JSContext*, JSValue)
    void JS_ResetUncatchableError(JSContext*)
    JSValue JS_NewError(JSContext*)
    JSValue JS_NewInternalError(JSContext*, const char*, ...)
    JSValue JS_NewPlainError(JSContext*, const char*, ...)
    JSValue JS_NewRangeError(JSContext*, const char*, ...)
    JSValue JS_NewReferenceError(JSContext*, const char*, ...)
    JSValue JS_NewSyntaxError(JSContext*, const char*, ...)
    JSValue JS_NewTypeError(JSContext*, const char*, ...)
    JSValue JS_ThrowInternalError(JSContext*, const char*, ...)
    JSValue JS_ThrowPlainError(JSContext*, const char*, ...)
    JSValue JS_ThrowRangeError(JSContext*, const char*, ...)
    JSValue JS_ThrowReferenceError(JSContext*, const char*, ...)
    JSValue JS_ThrowSyntaxError(JSContext*, const char*, ...)
    JSValue JS_ThrowTypeError(JSContext*, const char*, ...)
    JSValue JS_ThrowDOMException(JSContext*, const char*, const char*, ...)
    JSValue JS_ThrowOutOfMemory(JSContext*)
    void JS_FreeValue(JSContext*, JSValue)
    void JS_FreeValueRT(JSRuntime*, JSValue)
    JSValue JS_DupValue(JSContext*, JSValue)
    JSValue JS_DupValueRT(JSRuntime*, JSValue)
    int JS_ToBool(JSContext*, JSValue)
    JSValue JS_ToBoolean(JSContext*, JSValue)
    JSValue JS_ToNumber(JSContext*, JSValue)
    int JS_ToInt32(JSContext*, int32_t*, JSValue)
    int JS_ToUint32(JSContext*, uint32_t*, JSValue)
    int JS_ToInt64(JSContext*, int64_t*, JSValue)
    int JS_ToIndex(JSContext*, uint64_t*, JSValue)
    int JS_ToFloat64(JSContext*, double*, JSValue)
    int JS_ToBigInt64(JSContext*, int64_t*, JSValue)
    int JS_ToBigUint64(JSContext*, uint64_t*, JSValue)
    int JS_ToInt64Ext(JSContext*, int64_t*, JSValue)
    JSValue JS_NewStringLen(JSContext*, const char*, size_t)
    JSValue JS_NewString(JSContext*, const char*)
    JSValue JS_NewTwoByteString(JSContext*, uint16_t*, size_t)
    JSValue JS_NewAtomString(JSContext*, const char*)
    JSValue JS_ToString(JSContext*, JSValue)
    JSValue JS_ToPropertyKey(JSContext*, JSValue)
    const char* JS_ToCStringLen2(JSContext*, size_t*, JSValue, bint)
    const char* JS_ToCStringLen(JSContext*, size_t*, JSValue)
    const char* JS_ToCString(JSContext*, JSValue)
    void JS_FreeCString(JSContext*, const char*)
    void JS_FreeCStringRT(JSRuntime*, const char*)
    JSValue JS_NewObjectProtoClass(JSContext*, JSValue, JSClassID)
    JSValue JS_NewObjectClass(JSContext*, JSClassID)
    JSValue JS_NewObjectProto(JSContext*, JSValue)
    JSValue JS_NewObject(JSContext*)
    JSValue JS_NewObjectFrom(JSContext*, int, JSAtom*, JSValue*)
    JSValue JS_NewObjectFromStr(JSContext*, int, const char**, JSValue*)
    JSValue JS_ToObject(JSContext*, JSValue)
    JSValue JS_ToObjectString(JSContext*, JSValue)
    bint JS_IsFunction(JSContext*, JSValue)
    bint JS_IsConstructor(JSContext*, JSValue)
    bint JS_SetConstructorBit(JSContext*, JSValue, bint)
    bint JS_IsRegExp(JSValue)
    bint JS_IsMap(JSValue)
    bint JS_IsSet(JSValue)
    bint JS_IsWeakRef(JSValue)
    bint JS_IsWeakSet(JSValue)
    bint JS_IsWeakMap(JSValue)
    bint JS_IsDataView(JSValue)
    JSValue JS_NewArray(JSContext*)
    JSValue JS_NewArrayFrom(JSContext*, int, JSValue*)
    bint JS_IsArray(JSValue)
    bint JS_IsProxy(JSValue)
    JSValue JS_GetProxyTarget(JSContext*, JSValue)
    JSValue JS_GetProxyHandler(JSContext*, JSValue)
    JSValue JS_NewProxy(JSContext*, JSValue, JSValue)
    JSValue JS_NewDate(JSContext*, double)
    bint JS_IsDate(JSValue)
    JSValue JS_GetProperty(JSContext*, JSValue, JSAtom)
    JSValue JS_GetPropertyUint32(JSContext*, JSValue, uint32_t)
    JSValue JS_GetPropertyInt64(JSContext*, JSValue, int64_t)
    JSValue JS_GetPropertyStr(JSContext*, JSValue, const char*)
    int JS_SetProperty(JSContext*, JSValue, JSAtom, JSValue)
    int JS_SetPropertyUint32(JSContext*, JSValue, uint32_t, JSValue)
    int JS_SetPropertyInt64(JSContext*, JSValue, int64_t, JSValue)
    int JS_SetPropertyStr(JSContext*, JSValue, const char*, JSValue)
    int JS_HasProperty(JSContext*, JSValue, JSAtom)
    int JS_IsExtensible(JSContext*, JSValue)
    int JS_PreventExtensions(JSContext*, JSValue)
    int JS_DeleteProperty(JSContext*, JSValue, JSAtom, int)
    int JS_SetPrototype(JSContext*, JSValue, JSValue)
    JSValue JS_GetPrototype(JSContext*, JSValue)
    int JS_GetLength(JSContext*, JSValue, int64_t*)
    int JS_SetLength(JSContext*, JSValue, int64_t)
    int JS_SealObject(JSContext*, JSValue)
    int JS_FreezeObject(JSContext*, JSValue)
    int JS_GetOwnPropertyNames(JSContext*, JSPropertyEnum**, uint32_t*, JSValue, int)
    int JS_GetOwnProperty(JSContext*, JSPropertyDescriptor*, JSValue, JSAtom)
    void JS_FreePropertyEnum(JSContext*, JSPropertyEnum*, uint32_t)
    JSValue JS_Call(JSContext*, JSValue, JSValue, int, JSValue*)
    JSValue JS_Invoke(JSContext*, JSValue, JSAtom, int, JSValue*)
    JSValue JS_CallConstructor(JSContext*, JSValue, int, JSValue*)
    JSValue JS_CallConstructor2(JSContext*, JSValue, JSValue, int, JSValue*)
    bint JS_DetectModule(const char*, size_t)
    JSValue JS_Eval(JSContext*, const char*, size_t, const char*, int)
    JSValue JS_Eval2(JSContext*, const char*, size_t, JSEvalOptions*)
    JSValue JS_EvalThis(JSContext*, JSValue, const char*, size_t, const char*, int)
    JSValue JS_EvalThis2(JSContext*, JSValue, const char*, size_t, JSEvalOptions*)
    JSValue JS_GetGlobalObject(JSContext*)
    int JS_IsInstanceOf(JSContext*, JSValue, JSValue)
    int JS_DefineProperty(JSContext*, JSValue, JSAtom, JSValue, JSValue, JSValue, int)
    int JS_DefinePropertyValue(JSContext*, JSValue, JSAtom, JSValue, int)
    int JS_DefinePropertyValueUint32(JSContext*, JSValue, uint32_t, JSValue, int)
    int JS_DefinePropertyValueStr(JSContext*, JSValue, const char*, JSValue, int)
    int JS_DefinePropertyGetSet(JSContext*, JSValue, JSAtom, JSValue, JSValue, int)
    int JS_SetOpaque(JSValue, void*)
    void* JS_GetOpaque(JSValue, JSClassID)
    void* JS_GetOpaque2(JSContext*, JSValue, JSClassID)
    void* JS_GetAnyOpaque(JSValue, JSClassID*)
    JSValue JS_ParseJSON(JSContext*, const char*, size_t, const char*)
    JSValue JS_UNDEFINED
    JSValue JS_JSONStringify(JSContext*, JSValue, JSValue, JSValue)
    ctypedef void JSFreeArrayBufferDataFunc(JSRuntime*, void*, void*)
    JSValue JS_NewArrayBuffer(JSContext*, uint8_t*, size_t, JSFreeArrayBufferDataFunc*, void*, bint)
    JSValue JS_NewArrayBufferCopy(JSContext*, uint8_t*, size_t)
    void JS_DetachArrayBuffer(JSContext*, JSValue)
    uint8_t* JS_GetArrayBuffer(JSContext*, size_t*, JSValue)
    bint JS_IsArrayBuffer(JSValue)
    uint8_t* JS_GetUint8Array(JSContext*, size_t*, JSValue)
    enum JSTypedArrayEnum:
        JS_TYPED_ARRAY_UINT8C = 0
        JS_TYPED_ARRAY_INT8 = 1
        JS_TYPED_ARRAY_UINT8 = 2
        JS_TYPED_ARRAY_INT16 = 3
        JS_TYPED_ARRAY_UINT16 = 4
        JS_TYPED_ARRAY_INT32 = 5
        JS_TYPED_ARRAY_UINT32 = 6
        JS_TYPED_ARRAY_BIG_INT64 = 7
        JS_TYPED_ARRAY_BIG_UINT64 = 8
        JS_TYPED_ARRAY_FLOAT16 = 9
        JS_TYPED_ARRAY_FLOAT32 = 10
        JS_TYPED_ARRAY_FLOAT64 = 11
    ctypedef JSTypedArrayEnum JSTypedArrayEnum
    JSValue JS_NewTypedArray(JSContext*, int, JSValue*, JSTypedArrayEnum)
    JSValue JS_GetTypedArrayBuffer(JSContext*, JSValue, size_t*, size_t*, size_t*)
    JSValue JS_NewUint8Array(JSContext*, uint8_t*, size_t, JSFreeArrayBufferDataFunc*, void*, bint)
    int JS_GetTypedArrayType(JSValue)
    JSValue JS_NewUint8ArrayCopy(JSContext*, uint8_t*, size_t)
    struct JSSharedArrayBufferFunctions:
        void* (*sab_alloc)(void*, size_t)
        void (*sab_free)(void*, void*)
        void (*sab_dup)(void*, void*)
        void* sab_opaque
    ctypedef JSSharedArrayBufferFunctions JSSharedArrayBufferFunctions
    void JS_SetSharedArrayBufferFunctions(JSRuntime*, JSSharedArrayBufferFunctions*)
    enum JSPromiseStateEnum:
        JS_PROMISE_NOT_A_PROMISE = -1
        JS_PROMISE_PENDING = 0
        JS_PROMISE_FULFILLED = 1
        JS_PROMISE_REJECTED = 2
    ctypedef JSPromiseStateEnum JSPromiseStateEnum
    JSValue JS_NewPromiseCapability(JSContext*, JSValue*)
    JSPromiseStateEnum JS_PromiseState(JSContext*, JSValue)
    JSValue JS_PromiseResult(JSContext*, JSValue)
    bint JS_IsPromise(JSValue)
    JSValue JS_NewSymbol(JSContext*, const char*, bint)
    enum JSPromiseHookType:
        JS_PROMISE_HOOK_INIT = 0
        JS_PROMISE_HOOK_BEFORE = 1
        JS_PROMISE_HOOK_AFTER = 2
        JS_PROMISE_HOOK_RESOLVE = 3
    ctypedef JSPromiseHookType JSPromiseHookType
    ctypedef void (*JSPromiseHook)(JSContext*, JSPromiseHookType, JSValue, JSValue, void*)
    void JS_SetPromiseHook(JSRuntime*, JSPromiseHook, void*)
    ctypedef void (*JSHostPromiseRejectionTracker)(JSContext*, JSValue, JSValue, bint, void*)
    void JS_SetHostPromiseRejectionTracker(JSRuntime*, JSHostPromiseRejectionTracker*, void*)
    ctypedef int (*JSInterruptHandler)(JSRuntime*, void*)
    void JS_SetInterruptHandler(JSRuntime*, JSInterruptHandler*, void*)
    void JS_SetCanBlock(JSRuntime*, bint)
    void JS_SetIsHTMLDDA(JSContext*, JSValue)
    ctypedef JSModuleDef JSModuleDef
    ctypedef char* (*JSModuleNormalizeFunc)(JSContext*, const char*, const char*, void*)
    ctypedef JSModuleDef* (*JSModuleLoaderFunc)(JSContext*, const char*, void*)
    void JS_SetModuleLoaderFunc(JSRuntime*, JSModuleNormalizeFunc*, JSModuleLoaderFunc*, void*)
    JSValue JS_GetImportMeta(JSContext*, JSModuleDef*)
    JSAtom JS_GetModuleName(JSContext*, JSModuleDef*)
    JSValue JS_GetModuleNamespace(JSContext*, JSModuleDef*)
    ctypedef JSValue (*JSJobFunc)(JSContext*, int, JSValue*)
    int JS_EnqueueJob(JSContext*, JSJobFunc*, int, JSValue*)
    bint JS_IsJobPending(JSRuntime*)
    int JS_ExecutePendingJob(JSRuntime*, JSContext**)
    struct JSSABTab:
        uint8_t** tab
        size_t len
    ctypedef JSSABTab JSSABTab
    uint8_t* JS_WriteObject(JSContext*, size_t*, JSValue, int)
    uint8_t* JS_WriteObject2(JSContext*, size_t*, JSValue, int, JSSABTab*)
    JSValue JS_ReadObject(JSContext*, uint8_t*, size_t, int)
    JSValue JS_ReadObject2(JSContext*, uint8_t*, size_t, int, JSSABTab*)
    JSValue JS_EvalFunction(JSContext*, JSValue)
    int JS_ResolveModule(JSContext*, JSValue)
    JSAtom JS_GetScriptOrModuleName(JSContext*, int)
    JSValue JS_LoadModule(JSContext*, const char*, const char*)
    enum JSCFunctionEnum:
        JS_CFUNC_generic = 0
        JS_CFUNC_generic_magic = 1
        JS_CFUNC_constructor = 2
        JS_CFUNC_constructor_magic = 3
        JS_CFUNC_constructor_or_func = 4
        JS_CFUNC_constructor_or_func_magic = 5
        JS_CFUNC_f_f = 6
        JS_CFUNC_f_f_f = 7
        JS_CFUNC_getter = 8
        JS_CFUNC_setter = 9
        JS_CFUNC_getter_magic = 10
        JS_CFUNC_setter_magic = 11
        JS_CFUNC_iterator_next = 12
    ctypedef JSCFunctionEnum JSCFunctionEnum
    union JSCFunctionType:
        JSCFunction* generic
        JSValue (*generic_magic)(JSContext*, JSValue, int, JSValue*, int)
        JSCFunction* constructor
        JSValue (*constructor_magic)(JSContext*, JSValue, int, JSValue*, int)
        JSCFunction* constructor_or_func
        double (*f_f)(double)
        double (*f_f_f)(double, double)
        JSValue (*getter)(JSContext*, JSValue)
        JSValue (*setter)(JSContext*, JSValue, JSValue)
        JSValue (*getter_magic)(JSContext*, JSValue, int)
        JSValue (*setter_magic)(JSContext*, JSValue, JSValue, int)
        JSValue (*iterator_next)(JSContext*, JSValue, int, JSValue*, int*, int)
    ctypedef JSCFunctionType JSCFunctionType
    JSValue JS_NewCFunction2(JSContext*, JSCFunction*, const char*, int, JSCFunctionEnum, int)
    JSValue JS_NewCFunction3(JSContext*, JSCFunction*, const char*, int, JSCFunctionEnum, int, JSValue)
    JSValue JS_NewCFunctionData(JSContext*, JSCFunctionData*, int, int, int, JSValue*)
    JSValue JS_NewCFunctionData2(JSContext*, JSCFunctionData*, const char*, int, int, int, JSValue*)
    ctypedef void (*JSCClosureFinalizerFunc)(void*)
    JSValue JS_NewCClosure(JSContext*, JSCClosure*, const char*, JSCClosureFinalizerFunc*, int, int, void*)
    JSValue JS_NewCFunction(JSContext*, JSCFunction*, const char*, int)
    JSValue JS_NewCFunctionMagic(JSContext*, JSCFunctionMagic*, const char*, int, JSCFunctionEnum, int)
    void JS_SetConstructor(JSContext*, JSValue, JSValue)
    struct pxdgen_anon_pxdgen_anon_JSCFunctionListEntry_0_0:
        JSCFunctionListEntry* tab
        int len
    struct pxdgen_anon_pxdgen_anon_JSCFunctionListEntry_0_1:
        const char* name
        int base
    struct pxdgen_anon_pxdgen_anon_JSCFunctionListEntry_0_2:
        JSCFunctionType get
        JSCFunctionType set
    struct pxdgen_anon_pxdgen_anon_JSCFunctionListEntry_0_3:
        uint8_t length
        uint8_t cproto
        JSCFunctionType cfunc
    union pxdgen_anon_JSCFunctionListEntry_0:
        pxdgen_anon_pxdgen_anon_JSCFunctionListEntry_0_3 func
        pxdgen_anon_pxdgen_anon_JSCFunctionListEntry_0_2 getset
        pxdgen_anon_pxdgen_anon_JSCFunctionListEntry_0_1 alias
        pxdgen_anon_pxdgen_anon_JSCFunctionListEntry_0_0 prop_list
        const char* str
        int32_t i32
        int64_t i64
        uint64_t u64
        double f64
    struct JSCFunctionListEntry:
        const char* name
        uint8_t prop_flags
        uint8_t def_type
        int16_t magic
        pxdgen_anon_JSCFunctionListEntry_0 u
    ctypedef JSCFunctionListEntry JSCFunctionListEntry
    int JS_SetPropertyFunctionList(JSContext*, JSValue, JSCFunctionListEntry*, int)
    ctypedef int (*JSModuleInitFunc)(JSContext*, JSModuleDef*)
    JSModuleDef* JS_NewCModule(JSContext*, const char*, JSModuleInitFunc*)
    int JS_AddModuleExport(JSContext*, JSModuleDef*, const char*)
    int JS_AddModuleExportList(JSContext*, JSModuleDef*, JSCFunctionListEntry*, int)
    int JS_SetModuleExport(JSContext*, JSModuleDef*, const char*, JSValue)
    int JS_SetModuleExportList(JSContext*, JSModuleDef*, JSCFunctionListEntry*, int)
    const char* JS_GetVersion()
    uintptr_t js_std_cmd(int, ...)

    # Pre-defined
    int32_t JS_VALUE_GET_TAG(JSValue v)
    
