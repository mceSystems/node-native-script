//
//  AllocatedPlaceholder.cpp
//  NativeScript
//
//  Created by Ivan Buhov on 7/9/15.
//  Copyright (c) 2015 Telerik. All rights reserved.
//

#include "jsc-includes.h"
#include "AllocatedPlaceholder.h"

namespace NativeScript {
using namespace JSC;

const ClassInfo AllocatedPlaceholder::s_info = { "AllocatedPlaceholder", &Base::s_info, nullptr, nullptr, CREATE_METHOD_TABLE(AllocatedPlaceholder) };

void AllocatedPlaceholder::visitChildren(JSCell* cell, JSC::SlotVisitor& visitor) {
    Base::visitChildren(cell, visitor);

    AllocatedPlaceholder* object = jsCast<AllocatedPlaceholder*>(cell);

    visitor.append(object->_instanceStructure);
}
} // namespace NativeScript
