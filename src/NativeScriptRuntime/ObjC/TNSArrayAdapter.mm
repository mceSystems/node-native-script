//
//  TNSArrayAdapter.m
//  NativeScript
//
//  Created by Yavor Georgiev on 27.03.15.
//  Copyright (c) 2015 г. Telerik. All rights reserved.
//

#include "jsc-includes.h"
#import "TNSArrayAdapter.h"
#include "Interop.h"
#include "ObjCTypes.h"
#include <JavaScriptCore/JSObject.h>
#include <JavaScriptCore/StrongInlines.h>

using namespace NativeScript;
using namespace JSC;

@implementation TNSArrayAdapter {
    Strong<JSObject> _object;
    ExecState* _execState;
    VM* _vm;
}

- (instancetype)initWithJSObject:(JSObject*)jsObject execState:(ExecState*)execState {
    if (self) {
        self->_object = Strong<JSObject>(execState->vm(), jsObject);
        self->_execState = execState;
        self->_vm = &execState->vm();
        NativeScriptRuntime::getRuntime(execState)->objectMap()->set(self, jsObject);
    }

    return self;
}

- (NSUInteger)count {
    //RELEASE_ASSERT_WITH_MESSAGE([TNSRuntime runtimeForVM:self->_vm], "The runtime is deallocated.");
    RuntimeLockHolder lockHolder(self->_vm);

    JSObject* object = self->_object.get();
    if (JSArray* array = jsDynamicCast<JSArray*>(self->_execState->vm(), object)) {
        return array->length();
    }

    return object->get(self->_execState, self->_execState->vm().propertyNames->length).toUInt32(self->_execState);
}

- (id)objectAtIndex:(NSUInteger)index {
    //RELEASE_ASSERT_WITH_MESSAGE([TNSRuntime runtimeForVM:self->_vm], "The runtime is deallocated.");
    if (!(index < [self count])) {
        @throw [NSException exceptionWithName:NSRangeException reason:[NSString stringWithFormat:@"Index (%tu) out of bounds", index] userInfo:nil];
    }

    RuntimeLockHolder lockHolder(self->_vm);
    return toObject(self->_execState, self->_object.get()->get(self->_execState, index));
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id[])buffer count:(NSUInteger)len {
    //RELEASE_ASSERT_WITH_MESSAGE([TNSRuntime runtimeForVM:self->_vm], "The runtime is deallocated.");
    if (state->state == 0) { // uninitialized
        state->state = 1;
        state->mutationsPtr = reinterpret_cast<unsigned long*>(self);
        state->extra[0] = 0; // current index
        state->extra[1] = self->_object->get(self->_execState, self->_vm->propertyNames->length).toUInt32(self->_execState);
    }

    NSUInteger currentIndex = state->extra[0];
    unsigned int length = state->extra[1];
    NSUInteger count = 0;
    state->itemsPtr = buffer;

    RuntimeLockHolder lockHolder(self->_vm);
    while (count < len && currentIndex < length) {
        *buffer++ = toObject(self->_execState, self->_object->get(self->_execState, currentIndex));
        currentIndex++;
        count++;
    }

    state->extra[0] = currentIndex;

    return count;
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
