//
//  createNativeScriptRuntime.mm
//  node-native-script
//
//  Copyright (c) 2018 mce Sys Ltd. All rights reserved.
//

#include "jsc-includes.h"
#include "NativeScriptRuntime/NativeScriptRuntime.h"
#include "NativeScriptRuntime/Metadata/Metadata.h"
#include "createNativeScriptRuntime.h"

#include <JavaScriptCore/JSGlobalObject.h>

int64_t createNativeScriptRuntime(v8::Context * context, void * uncaughtErrorHandler, uv_loop_t * eventLoop, NativeScriptRuntimeLockHooks * runtimeLockHooks)
{
    extern char startOfMetadataSection __asm("section$start$__DATA$__TNSMetadata");
    Metadata::MetaFile::setInstance(&startOfMetadataSection);

    JSC::JSValue globalValue = *(reinterpret_cast<JSC::JSValue *>(context));
    JSC::JSGlobalObject * globalObject = reinterpret_cast<JSC::JSGlobalObject *>(globalValue.asCell());
    JSC::VM& vm = globalObject->vm();

    NativeScript::RuntimeLock::Hooks nativeScriptLockHooks { runtimeLockHooks->lockedHook, runtimeLockHooks->unlockedHook, runtimeLockHooks->context };
    NativeScript::NativeScriptRuntime * runtime = NativeScript::NativeScriptRuntime::create(vm, 
                                                                                            globalObject,
                                                                                            NativeScript::NativeScriptRuntime::createStructure(vm, globalObject, JSC::jsNull()),
                                                                                            reinterpret_cast<NativeScript::NativeScriptRuntime::UncaughtErrorHandler>(uncaughtErrorHandler),
                                                                                            eventLoop,
                                                                                            &nativeScriptLockHooks);
    /* TODO: For now, int64_t is used instead of JSC::JSValue because I've had issues with it I need to investigate.
     * Butm while JSC::JSValues are always 64bit, this cast only works for 64bit, which fine for now since we only
     * support 64bit anyway. */
    return reinterpret_cast<int64_t>(runtime);
}
