//
//  ReferenceTypeConstructor.h
//  NativeScript
//
//  Created by Ivan Buhov on 11/3/14.
//  Copyright (c) 2014 Telerik. All rights reserved.
//

#ifndef __NativeScript__ReferenceTypeConstructor__
#define __NativeScript__ReferenceTypeConstructor__

#include <JavaScriptCore/InternalFunction.h>

namespace NativeScript {

class ReferenceTypeConstructor : public JSC::InternalFunction {
public:
    typedef JSC::InternalFunction Base;

    static ReferenceTypeConstructor* create(JSC::VM& vm, JSC::Structure* structure, JSObject* referenceTypePrototype) {
        ReferenceTypeConstructor* constructor = new (NotNull, JSC::allocateCell<ReferenceTypeConstructor>(vm.heap)) ReferenceTypeConstructor(vm, structure);
        constructor->finishCreation(vm, referenceTypePrototype);
        return constructor;
    }

    DECLARE_INFO;

    static JSC::Structure* createStructure(JSC::VM& vm, JSC::JSGlobalObject* globalObject, JSC::JSValue prototype) {
        return JSC::Structure::create(vm, globalObject, prototype, JSC::TypeInfo(JSC::InternalFunctionType, StructureFlags), info());
    }

private:
    ReferenceTypeConstructor(JSC::VM& vm, JSC::Structure* structure)
        : Base(vm, structure, &constructReferenceType, &constructReferenceType) {
    }

    void finishCreation(JSC::VM&, JSObject*);

    static JSC::EncodedJSValue JSC_HOST_CALL constructReferenceType(JSC::ExecState* execState);
};
} // namespace NativeScript

#endif /* defined(__NativeScript__ReferenceTypeConstructor__) */
