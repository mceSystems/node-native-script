//
//  createNativeScriptRuntime.h
//  node-native-script
//
//  Copyright (c) 2018 mce Sys Ltd. All rights reserved.
//

#pragma once

namespace v8
{
    class Context;
}

struct uv_loop_s;
typedef struct uv_loop_s uv_loop_t;

struct NativeScriptRuntimeLockHooks {
    using HookCallback = void (*)(void * context);

    HookCallback lockedHook;
    HookCallback unlockedHook;
    void * context;
};

int64_t createNativeScriptRuntime(v8::Context * context, void * uncaughtErrorHandler, uv_loop_t * eventLoop, NativeScriptRuntimeLockHooks * runtimeLockHooks);