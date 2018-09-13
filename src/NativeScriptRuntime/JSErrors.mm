//
//  JSErrors.mm
//  NativeScript
//
//  Created by Jason Zhekov on 2/26/15.
//  Copyright (c) 2015 Telerik. All rights reserved.
//

#include "jsc-includes.h"
#include "JSErrors.h"
#include "NativeScriptRuntime.h"

namespace NativeScript {

using namespace JSC;

void reportFatalErrorBeforeShutdown(ExecState* execState, Exception* exception, bool callUncaughtErrorCallbacks) {
    NativeScriptRuntime::getRuntime(execState)->callUncaughtErrorHandler(exception->value());

    *(int*)(uintptr_t)0xDEADDEAD = 0;
    __builtin_trap();
}

}
