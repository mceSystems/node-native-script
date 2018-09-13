//
//  NSErrorWrapperConstructor.mm
//  NativeScript
//
//  Created by Yavor Georgiev on 30.12.15 г..
//  Copyright (c) 2015 Telerik. All rights reserved.
//

#include "jsc-includes.h"
#include "NSErrorWrapperConstructor.h"
#include "JSStringUtils.h"
#include "ObjCTypes.h"
#include <JavaScriptCore/Error.h>
#include <JavaScriptCore/ErrorPrototype.h>
#include <JavaScriptCore/JSGlobalObject.h>

namespace NativeScript {
using namespace JSC;

const ClassInfo NSErrorWrapperConstructor::s_info = { "NSErrorWrapper", &Base::s_info, nullptr, nullptr, CREATE_METHOD_TABLE(NSErrorWrapperConstructor) };

void NSErrorWrapperConstructor::destroy(JSCell* cell) {
    static_cast<NSErrorWrapperConstructor*>(cell)->~NSErrorWrapperConstructor();
}

void NSErrorWrapperConstructor::finishCreation(VM& vm, JSGlobalObject* globalObject) {
    Base::finishCreation(vm, WTF::ASCIILiteral("NSError"));

    ErrorPrototype* prototype = ErrorPrototype::create(vm, globalObject, ErrorPrototype::createStructure(vm, globalObject, globalObject->errorPrototype()));
    prototype->putDirect(vm, vm.propertyNames->constructor, this);
    this->putDirect(vm, vm.propertyNames->prototype, prototype);
    prototype->putDirect(vm, vm.propertyNames->name, jsString(&vm, WTF::ASCIILiteral("NSErrorWrapper")));

    this->_errorStructure.set(vm, this, ErrorInstance::createStructure(vm, globalObject, prototype));
}

void NSErrorWrapperConstructor::visitChildren(JSCell* cell, SlotVisitor& slotVisitor) {
    Base::visitChildren(cell, slotVisitor);

    NSErrorWrapperConstructor* self = jsCast<NSErrorWrapperConstructor*>(cell);
    slotVisitor.append(self->_errorStructure);
}

ErrorInstance* NSErrorWrapperConstructor::createError(ExecState* execState, NSError* error) const {
    VM& vm = execState->vm();
    ErrorInstance* wrappedError = ErrorInstance::create(execState, vm, this->errorStructure(), CFStringToWTFString(reinterpret_cast<CFStringRef>(error.localizedDescription)));
    wrappedError->putDirect(vm, Identifier::fromString(execState, "error"), NativeScript::toValue(execState, error));

    return wrappedError;
}

EncodedJSValue JSC_HOST_CALL NSErrorWrapperConstructor::constructErrorWrapper(ExecState* execState) {
    NSErrorWrapperConstructor* self = jsCast<NSErrorWrapperConstructor*>(execState->callee().asCell());
    NSError* error = NativeScript::toObject(execState, execState->argument(0));

    if (!error || ![error isKindOfClass:[NSError class]]) {
        JSC::VM& vm = execState->vm();
        auto scope = DECLARE_THROW_SCOPE(vm);

        return throwVMTypeError(execState, scope);
    }

    return JSValue::encode(self->createError(execState, error));
}
}
