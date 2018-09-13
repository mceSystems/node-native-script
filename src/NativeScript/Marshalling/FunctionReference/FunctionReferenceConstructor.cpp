//
//  FunctionReferenceConstructor.cpp
//  NativeScript
//
//  Created by Jason Zhekov on 10/20/14.
//  Copyright (c) 2014 Telerik. All rights reserved.
//

#include "FunctionReferenceConstructor.h"
#include "FunctionReferenceInstance.h"
#include "Interop.h"

namespace NativeScript {
using namespace JSC;

const ClassInfo FunctionReferenceConstructor::s_info = { "FunctionReference", &Base::s_info, nullptr, nullptr, CREATE_METHOD_TABLE(FunctionReferenceConstructor) };

void FunctionReferenceConstructor::finishCreation(VM& vm, JSValue prototype) {
    Base::finishCreation(vm, this->classInfo()->className);
    this->putDirect(vm, vm.propertyNames->prototype, prototype, PropertyAttribute::DontEnum | PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly);
    this->putDirect(vm, vm.propertyNames->length, jsNumber(1), PropertyAttribute::ReadOnly | PropertyAttribute::DontEnum | PropertyAttribute::DontDelete);
}

EncodedJSValue JSC_HOST_CALL FunctionReferenceConstructor::constructFunctionReferenceInstance(ExecState* execState) {
    CallData callData;

    if (!(execState->argumentCount() == 1 && JSC::getCallData(execState->uncheckedArgument(0), callData) != CallType::None)) {
        JSC::VM& vm = execState->vm();
        auto scope = DECLARE_THROW_SCOPE(vm);

        return JSValue::encode(scope.throwException(execState, createError(execState, WTF::ASCIILiteral("Function required."))));
    }

    GlobalObject* globalObject = jsCast<GlobalObject*>(execState->lexicalGlobalObject());
    JSCell* func = execState->uncheckedArgument(0).asCell();
    FunctionReferenceInstance* functionReference = FunctionReferenceInstance::create(execState->vm(), globalObject, globalObject->interop()->functionReferenceInstanceStructure(), func);
    return JSValue::encode(functionReference);
}

} // namespace NativeScript
