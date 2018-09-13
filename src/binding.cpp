//
//  binding.cpp
//  node-native-script
//
//  Copyright (c) 2018 mce Sys Ltd. All rights reserved.
//

#include <nan.h>
#include "createNativeScriptRuntime.h"

namespace 
{

void uncaughtNativeScriptErrorHandler(JSC::JSValue error) {
    // Must be non verbose, so node::FatalException will do it's work
    Nan::TryCatch trayCatch;

    v8::Local<v8::Value> v8Error;
    *(reinterpret_cast<JSC::JSValue *>(&v8Error)) = error;
    Nan::ThrowError(v8Error);
    
    Nan::FatalException(trayCatch);

    // Make sure we never return from this function 
     *(int*)(uintptr_t)0xDEADDEAD = 0;
    __builtin_trap();
}

void NativeScriptRuntimeLockHook(void * context) {
    reinterpret_cast<v8::Isolate *>(context)->Enter();
}

void NativeScriptRuntimeUnlockHook(void * context) {
    reinterpret_cast<v8::Isolate *>(context)->Exit();
}

}

void Init(v8::Local<v8::Object> exports) {
    v8::Isolate * isolate = v8::Isolate::GetCurrent();
    v8::Local<v8::Object> nativeScriptRuntime;

    /* TODO: int64_t is used instead of JSC::JSValue because I've had issues with it I need to investigate.
     * For now we'll just use int64_t, which is the same size as JSC::JSValue */
    NativeScriptRuntimeLockHooks runtimeLockHooks = { NativeScriptRuntimeLockHook, NativeScriptRuntimeUnlockHook, reinterpret_cast<void *>(isolate) };
    int64_t runtime = createNativeScriptRuntime(*Nan::GetCurrentContext(), 
                                                reinterpret_cast<void *>(uncaughtNativeScriptErrorHandler), 
                                                node::GetCurrentEventLoop(isolate),
                                                &runtimeLockHooks);
    
    /* Set the nativeScriptRuntime underlying value to point to our new runtime
     * TODO: This is horrible, but v8::Local's val_ member is private */
    *(reinterpret_cast<int64_t *>(&nativeScriptRuntime)) = runtime;

    exports->Set(Nan::New("nativeScriptRuntime").ToLocalChecked(), nativeScriptRuntime);
}

NODE_MODULE(NativeScript, Init)