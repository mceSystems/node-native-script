//
//  TNSDataAdapter.mm
//  NativeScript
//
//  Created by Yavor Georgiev on 20.07.15.
//  Copyright (c) 2015 Telerik. All rights reserved.
//

#include "jsc-includes.h"
#import "TNSDataAdapter.h"
#include "Interop.h"
#include "JSErrors.h"
#include <JavaScriptCore/JSArrayBuffer.h>
#include <JavaScriptCore/JSArrayBufferView.h>
#include <JavaScriptCore/StrongInlines.h>

using namespace NativeScript;
using namespace JSC;

@implementation TNSDataAdapter {
    Strong<JSObject> _object;
    ExecState* _execState;
    VM* _vm;
}

- (instancetype)initWithJSObject:(JSObject*)jsObject execState:(ExecState*)execState {
    if (self) {
        self->_object.set(execState->vm(), jsObject);
        self->_execState = execState;
        self->_vm = &execState->vm();
        NativeScriptRuntime::getRuntime(execState)->objectMap()->set(self, jsObject);
    }

    return self;
}

- (const void*)bytes {
    return [self mutableBytes];
}

- (void*)mutableBytes {
    //RELEASE_ASSERT_WITH_MESSAGE([TNSRuntime runtimeForVM:self->_vm], "The runtime is deallocated.");
    RuntimeLockHolder lockHolder(self->_vm);

    if (JSArrayBuffer* arrayBuffer = jsDynamicCast<JSArrayBuffer*>(self->_execState->vm(), self->_object.get())) {
        return arrayBuffer->impl()->data();
    }

    JSArrayBufferView* arrayBufferView = jsCast<JSArrayBufferView*>(self->_object.get());
    if (arrayBufferView->hasArrayBuffer()) {
        return arrayBufferView->unsharedBuffer()->data();
    }

    return arrayBufferView->vector();
}

- (NSUInteger)length {
    //RELEASE_ASSERT_WITH_MESSAGE([TNSRuntime runtimeForVM:self->_vm], "The runtime is deallocated.");
    VM& vm = self->_execState->vm();
    RuntimeLockHolder lockHolder(self->_vm);
    auto scope = DECLARE_CATCH_SCOPE(vm);
    NSUInteger length = self->_object->get(self->_execState, vm.propertyNames->byteLength).toUInt32(self->_execState);
    reportErrorIfAny(self->_execState, scope);
    return length;
}

- (void)dealloc {
    {
        //if (TNSRuntime* runtime = [TNSRuntime runtimeForVM:self->_vm]) {
            RuntimeLockHolder lockHolder(self->_vm);
            NativeScriptRuntime::getRuntime(self->_execState)->objectMap()->remove(self);
        //}
    }

    [super dealloc];
}

@end
