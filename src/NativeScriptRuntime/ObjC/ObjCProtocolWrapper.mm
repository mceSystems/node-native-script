//
//  ObjCProtocolWrapper.mm
//  NativeScript
//
//  Created by Jason Zhekov on 8/8/14.
//  Copyright (c) 2014 Telerik. All rights reserved.
//

#include "jsc-includes.h"
#include "ObjCProtocolWrapper.h"
#include "Metadata.h"
#include "ObjCMethodCall.h"
#include "ObjCPrototype.h"
#include "SymbolLoader.h"

namespace NativeScript {
using namespace JSC;
using namespace Metadata;

const ClassInfo ObjCProtocolWrapper::s_info = { "ObjCProtocolWrapper", &Base::s_info, nullptr, nullptr, CREATE_METHOD_TABLE(ObjCProtocolWrapper) };

void ObjCProtocolWrapper::finishCreation(VM& vm, ObjCPrototype* prototype, const ProtocolMeta* metadata, Protocol* aProtocol) {
    Base::finishCreation(vm);
    this->putDirect(vm, vm.propertyNames->prototype, prototype, PropertyAttribute::DontEnum | PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly);
    this->_metadata = metadata;
    this->_protocol = aProtocol;
}

WTF::String ObjCProtocolWrapper::className(const JSObject* object) {
    ObjCProtocolWrapper* protocolWrapper = (ObjCProtocolWrapper*)object;
    const char* protocolName = protocolWrapper->metadata()->name();
    return protocolName;
}

bool ObjCProtocolWrapper::getOwnPropertySlot(JSObject* object, ExecState* execState, PropertyName propertyName, PropertySlot& propertySlot) {
    if (Base::getOwnPropertySlot(object, execState, propertyName, propertySlot)) {
        return true;
    }

    if (UNLIKELY(!propertyName.publicName())) {
        return false;
    }

    ObjCProtocolWrapper* protocol = jsCast<ObjCProtocolWrapper*>(object);

    if (const MethodMeta* method = protocol->_metadata->staticMethod(propertyName.publicName())) {
        SymbolLoader::instance().ensureModule(method->topLevelModule());

        NativeScriptRuntime* runtime = NativeScriptRuntime::getRuntime(execState);
        ObjCMethodCall* call = ObjCMethodCall::create(execState->vm(), execState->lexicalGlobalObject(), runtime->objCMethodCallStructure(), method);
        object->putDirect(execState->vm(), propertyName, call);
        propertySlot.setValue(object, static_cast<unsigned>(PropertyAttribute::None), call);
        return true;
    }

    return false;
}
};
