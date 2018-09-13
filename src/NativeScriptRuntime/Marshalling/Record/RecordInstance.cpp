//
//  RecordInstance.cpp
//  NativeScript
//
//  Created by Jason Zhekov on 10/13/14.
//  Copyright (c) 2014 Telerik. All rights reserved.
//

#include "jsc-includes.h"
#include "RecordInstance.h"
#include "Interop.h"

namespace NativeScript {
using namespace JSC;

const ClassInfo RecordInstance::s_info = { "record", &Base::s_info, nullptr, nullptr, CREATE_METHOD_TABLE(RecordInstance) };

void RecordInstance::finishCreation(VM& vm, JSGlobalObject* globalObject, size_t size, PointerInstance* pointer) {
    Base::finishCreation(vm);
    this->preventExtensions(this, vm.topCallFrame);

    this->_size = size;
    this->_pointer.set(vm, this, pointer);
}

void RecordInstance::visitChildren(JSCell* cell, SlotVisitor& visitor) {
    Base::visitChildren(cell, visitor);

    RecordInstance* object = jsCast<RecordInstance*>(cell);
    visitor.append(object->_pointer);
}
} // namespace NativeScript
