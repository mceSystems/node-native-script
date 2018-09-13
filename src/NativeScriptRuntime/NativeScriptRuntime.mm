//
//  NativeScriptRuntime.mm
//  NativeScript
//
//  Created by Yavor Georgiev on 14.07.14.
//  Copyright (c) 2014 г. Telerik. All rights reserved.
//

#include "jsc-includes.h"
#include "NativeScriptRuntime.h"
#include "AllocatedPlaceholder.h"
#include "FFICallPrototype.h"
#include "FFIFunctionCall.h"
#include "FFIFunctionCallback.h"
#include "FunctionReferenceInstance.h"
#include "Interop.h"
#include "JSWeakRefConstructor.h"
#include "JSWeakRefInstance.h"
#include "JSWeakRefPrototype.h"
#include "Metadata.h"
#include "NSErrorWrapperConstructor.h"
#include "ObjCBlockCall.h"
#include "ObjCBlockCallback.h"
#include "ObjCConstructorCall.h"
#include "ObjCConstructorDerived.h"
#include "ObjCConstructorNative.h"
#include "ObjCExtend.h"
#include "ObjCFastEnumerationIterator.h"
#include "ObjCFastEnumerationIteratorPrototype.h"
#include "ObjCMethodCall.h"
#include "ObjCMethodCallback.h"
#include "ObjCProtocolWrapper.h"
#include "ObjCPrototype.h"
#include "ObjCTypeScriptExtend.h"
#include "ObjCTypes.h"
#include "PointerConstructor.h"
#include "RecordConstructor.h"
#include "RecordPrototypeFunctions.h"
#include "SymbolLoader.h"
#include "TypeFactory.h"
#include "UnmanagedType.h"
#include "__extends.h"
#include "inlineFunctions.h"
#include <JavaScriptCore/Completion.h>
#include <JavaScriptCore/FunctionConstructor.h>
#include <JavaScriptCore/FunctionPrototype.h>
#include <JavaScriptCore/JSDestructibleObjectHeapCellType.h>
#include <JavaScriptCore/JSCInlines.h>
#include <JavaScriptCore/Microtask.h>
#include <JavaScriptCore/StrongInlines.h>
#include <JavaScriptCore/SourceCode.h>
#include <JavaScriptCore/VMEntryScope.h>
#include <string>

namespace NativeScript {
using namespace JSC;
using namespace Metadata;

JSC::EncodedJSValue JSC_HOST_CALL NSObjectAlloc(JSC::ExecState* execState) {
    ObjCConstructorBase* constructor = jsCast<ObjCConstructorBase*>(execState->thisValue().asCell());
    Class klass = constructor->klass();
    id instance = [klass alloc];

    if (ObjCConstructorDerived* constructorDerived = jsDynamicCast<ObjCConstructorDerived*>(execState->vm(), constructor)) {
        [instance release];
        JSValue jsValue = toValue(execState, instance, ^{
          return constructorDerived->instancesStructure();
        });
        return JSValue::encode(jsValue);
    } else if (ObjCConstructorNative* nativeConstructor = jsDynamicCast<ObjCConstructorNative*>(execState->vm(), constructor)) {
        AllocatedPlaceholder* allocatedPlaceholder = AllocatedPlaceholder::create(execState->vm(), nativeConstructor->allocatedPlaceholderStructure(), instance, nativeConstructor->instancesStructure());
        return JSValue::encode(allocatedPlaceholder);
    }

    ASSERT_NOT_REACHED();
    return JSValue::encode(jsUndefined());
}

static ObjCProtocolWrapper* createProtocolWrapper(JSC::JSGlobalObject* globalObject, const ProtocolMeta* protocolMeta, Protocol* aProtocol) {
    Structure* prototypeStructure = ObjCPrototype::createStructure(globalObject->vm(), globalObject, globalObject->objectPrototype());
    ObjCPrototype* prototype = ObjCPrototype::create(globalObject->vm(), globalObject, prototypeStructure, protocolMeta);
    Structure* protocolWrapperStructure = ObjCProtocolWrapper::createStructure(globalObject->vm(), globalObject, globalObject->objectPrototype());
    ObjCProtocolWrapper* protocolWrapper = ObjCProtocolWrapper::create(globalObject->vm(), protocolWrapperStructure, prototype, protocolMeta, aProtocol);
    prototype->materializeProperties(globalObject->vm(), globalObject);
    return protocolWrapper;
}

const ClassInfo NativeScriptRuntime::s_info = { "NativeScriptRuntime", &Base::s_info, nullptr, nullptr, CREATE_METHOD_TABLE(NativeScriptRuntime) };

JSC::Strong<NativeScriptRuntime> NativeScriptRuntime::s_runtimeInstance;

NativeScriptRuntime::NativeScriptRuntime(VM& vm, 
                                         Structure* structure, 
                                         UncaughtErrorHandler uncaughtErrorHandler, 
                                         uv_loop_t * eventLoop, 
                                         RuntimeLock::Hooks * runtimeLockHooks) : Base(vm, structure),
    _lock(&vm, eventLoop, runtimeLockHooks),
    _uncaughtErrorHandler(uncaughtErrorHandler) {

    vm.clientData = new VMData(vm);
}

// Because we hold a "strong" reference to our object, we'll only get destroyed when during the VM (and heap) destruction
NativeScriptRuntime::~NativeScriptRuntime() {
    s_runtimeInstance.clear();
}

void NativeScriptRuntime::finishCreation(VM& vm, JSC::JSGlobalObject* globalObject) {
    Base::finishCreation(vm);

    ASSERT(!s_runtimeInstance);
    s_runtimeInstance.set(vm, this);

    ExecState* globalExec = globalObject->globalExec();

    this->_objectMap = std::make_unique<JSC::WeakGCMap<id, JSC::JSObject>>(vm);

    this->putDirect(vm, vm.propertyNames->global, globalExec->globalThisValue(), static_cast<unsigned>(PropertyAttribute::DontEnum | PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly));

    this->_ffiCallPrototype.set(vm, this, FFICallPrototype::create(vm, globalObject, FFICallPrototype::createStructure(vm, globalObject, globalObject->functionPrototype())));
    this->_objCMethodCallStructure.set(vm, this, ObjCMethodCall::createStructure(vm, globalObject, this->ffiCallPrototype()));
    this->_objCConstructorCallStructure.set(vm, this, ObjCConstructorCall::createStructure(vm, globalObject, globalObject->functionPrototype()));
    this->_objCBlockCallStructure.set(vm, this, ObjCBlockCall::createStructure(vm, globalObject, this->ffiCallPrototype()));
    this->_ffiFunctionCallStructure.set(vm, this, FFIFunctionCall::createStructure(vm, globalObject, this->ffiCallPrototype()));
    this->_objCBlockCallbackStructure.set(vm, this, ObjCBlockCallback::createStructure(vm, globalObject, jsNull()));
    this->_objCMethodCallbackStructure.set(vm, this, ObjCMethodCallback::createStructure(vm, globalObject, jsNull()));
    this->_ffiFunctionCallbackStructure.set(vm, this, FFIFunctionCallback::createStructure(vm, globalObject, jsNull()));
    this->_recordFieldGetterStructure.set(vm, this, RecordProtoFieldGetter::createStructure(vm, globalObject, globalObject->functionPrototype()));
    this->_recordFieldSetterStructure.set(vm, this, RecordProtoFieldSetter::createStructure(vm, globalObject, globalObject->functionPrototype()));

    this->_typeFactory.set(vm, this, TypeFactory::create(vm, globalObject, TypeFactory::createStructure(vm, globalObject, jsNull())));

    this->_weakRefConstructorStructure.set(vm, this, JSWeakRefConstructor::createStructure(vm, globalObject, globalObject->functionPrototype()));
    this->_weakRefPrototypeStructure.set(vm, this, JSWeakRefPrototype::createStructure(vm, globalObject, globalObject->objectPrototype()));
    JSWeakRefPrototype* weakRefPrototype = JSWeakRefPrototype::create(vm, globalObject, this->weakRefPrototypeStructure());
    this->_weakRefInstanceStructure.set(vm, this, JSWeakRefInstance::createStructure(vm, globalObject, weakRefPrototype));
    this->putDirect(vm, Identifier::fromString(&vm, WTF::ASCIILiteral("WeakRef")), JSWeakRefConstructor::create(vm, this->weakRefConstructorStructure(), weakRefPrototype));

    auto fastEnumerationIteratorPrototype = ObjCFastEnumerationIteratorPrototype::create(vm, globalObject, ObjCFastEnumerationIteratorPrototype::createStructure(vm, globalObject, globalObject->objectPrototype()));
    this->_fastEnumerationIteratorStructure.set(vm, this, ObjCFastEnumerationIterator::createStructure(vm, globalObject, fastEnumerationIteratorPrototype));

    JSC::Structure* unmanagedPrototypeStructure = UnmanagedPrototype::createStructure(vm, globalObject, globalObject->objectPrototype());
    UnmanagedPrototype* unmanagedPrototype = UnmanagedPrototype::create(vm, globalObject, unmanagedPrototypeStructure);
    this->_unmanagedInstanceStructure.set(vm, this, UnmanagedInstance::createStructure(globalObject, unmanagedPrototype));

    this->_interopIdentifier = Identifier::fromString(&vm, Interop::info()->className);
    this->_interop.set(vm, this, Interop::create(vm, this, Interop::createStructure(vm, globalObject, globalObject->objectPrototype())));

#ifdef DEBUG
    SourceCode sourceCode = makeSource(WTF::String(__extends_js, __extends_js_len), SourceOrigin(), WTF::ASCIILiteral("__extends.ts"));
#else
    SourceCode sourceCode = makeSource(WTF::String(__extends_js, __extends_js_len), SourceOrigin());
#endif
    this->_typeScriptOriginalExtendsFunction.set(vm, this, jsCast<JSFunction*>(evaluate(globalExec, sourceCode, globalExec->thisValue())));
    this->putDirectNativeFunction(vm, globalObject, Identifier::fromString(globalExec, "__extends"), 2, ObjCTypeScriptExtendFunction, NoIntrinsic, static_cast<unsigned>(PropertyAttribute::DontEnum | PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly));

    ObjCConstructorNative* NSObjectConstructor = this->typeFactory()->NSObjectConstructor(globalObject);
    NSObjectConstructor->putDirectNativeFunction(vm, globalObject, Identifier::fromString(&vm, WTF::ASCIILiteral("extend")), 2, ObjCExtendFunction, NoIntrinsic, static_cast<unsigned>(PropertyAttribute::DontEnum));
    NSObjectConstructor->putDirectNativeFunction(vm, globalObject, Identifier::fromString(&vm, WTF::ASCIILiteral("alloc")), 0, NSObjectAlloc, NoIntrinsic, static_cast<unsigned>(PropertyAttribute::DontDelete));

    MarkedArgumentBuffer descriptionFunctionArgs;
    descriptionFunctionArgs.append(jsString(globalExec, WTF::ASCIILiteral("return this.description;")));
    ObjCPrototype* NSObjectPrototype = jsCast<ObjCPrototype*>(NSObjectConstructor->get(globalExec, vm.propertyNames->prototype));
    NSObjectPrototype->putDirect(vm, vm.propertyNames->toString, constructFunction(globalExec, globalObject, descriptionFunctionArgs), static_cast<unsigned>(PropertyAttribute::DontEnum));

    MarkedArgumentBuffer staticDescriptionFunctionArgs;
    staticDescriptionFunctionArgs.append(jsString(globalExec, WTF::ASCIILiteral("return Function.prototype.toString.call(this);")));
    NSObjectConstructor->putDirect(vm, vm.propertyNames->toString, constructFunction(globalExec, globalObject, staticDescriptionFunctionArgs), static_cast<unsigned>(PropertyAttribute::DontEnum));

    NSObjectConstructor->setPrototypeDirect(vm, NSObjectPrototype);

    // CFRunLoopSourceContext context = { 0, this, 0, 0, 0, 0, 0, 0, 0, microtaskRunLoopSourcePerformWork };
    // CFRunLoopObserverContext observerContext = { 0, this, NULL, NULL, NULL };

    // _microtaskRunLoopSource = WTF::adoptCF(CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context));
    // _runLoopBeforeWaitingObserver = WTF::adoptCF(CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, YES, 0, &runLoopBeforeWaitingPerformWork, &observerContext));

    this->putDirect(vm, Identifier::fromString(&vm, "__runtimeVersion"), jsString(&vm, STRINGIZE_VALUE_OF(NATIVESCRIPT_VERSION)), static_cast<unsigned>(PropertyAttribute::DontEnum | PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly));

    {
        NakedPtr<Exception> exception;
        JSFunction* inlineFunctions = jsCast<JSFunction*>(evaluate(globalExec, 
                                                                   makeSource(WTF::String(inlineFunctions_js, inlineFunctions_js_len), SourceOrigin()),
                                                                   JSValue(),
                                                                   exception));
        ASSERT_WITH_MESSAGE(!exception, "Error while evaluating inlineFunctions.js: %s", exception->value().toWTFString(globalExec).utf8().data());

        CallData callData;
        CallType callType = inlineFunctions->methodTable(vm)->getCallData(inlineFunctions, callData);
        ASSERT(JSC::CallType::None != callType);

        JSC::MarkedArgumentBuffer argList;
        argList.append(this);
        call(globalExec, inlineFunctions, callType, callData, globalExec->thisValue(), argList);
    }
}

NativeScriptRuntime::VMData::VMData(JSC::VM& vm) :
    _ffiFunctionCallSpace ISO_SUBSPACE_INIT(vm.heap, vm.destructibleObjectHeapCellType.get(), FFIFunctionCall),
    _functionReferenceInstanceSpace ISO_SUBSPACE_INIT(vm.heap, vm.destructibleObjectHeapCellType.get(), FunctionReferenceInstance),
    _nsErrorWrapperConstructorSpace ISO_SUBSPACE_INIT(vm.heap, vm.destructibleObjectHeapCellType.get(), NSErrorWrapperConstructor),
    _objCBlockCallSpace ISO_SUBSPACE_INIT(vm.heap, vm.destructibleObjectHeapCellType.get(), ObjCBlockCall),
    _objCConstructorCallSpace ISO_SUBSPACE_INIT(vm.heap, vm.destructibleObjectHeapCellType.get(), ObjCConstructorCall),
    _objCConstructorDerivedSpace ISO_SUBSPACE_INIT(vm.heap, vm.destructibleObjectHeapCellType.get(), ObjCConstructorDerived),
    _objCConstructorNativeSpace ISO_SUBSPACE_INIT(vm.heap, vm.destructibleObjectHeapCellType.get(), ObjCConstructorNative),
    _objCMethodCallSpace ISO_SUBSPACE_INIT(vm.heap, vm.destructibleObjectHeapCellType.get(), ObjCMethodCall),
    _pointerConstructorSpace ISO_SUBSPACE_INIT(vm.heap, vm.destructibleObjectHeapCellType.get(), PointerConstructor),
    _recordConstructorSpace ISO_SUBSPACE_INIT(vm.heap, vm.destructibleObjectHeapCellType.get(), RecordConstructor),
    _recordProtoFieldGetterSetterSpace ISO_SUBSPACE_INIT(vm.heap, vm.destructibleObjectHeapCellType.get(), RecordProtoFieldGetter)
{
}

void NativeScriptRuntime::visitChildren(JSCell* cell, SlotVisitor& visitor) {
    NativeScriptRuntime* nativeScriptRuntime = jsCast<NativeScriptRuntime*>(cell);
    Base::visitChildren(nativeScriptRuntime, visitor);

    visitor.append(nativeScriptRuntime->_interop);
    visitor.append(nativeScriptRuntime->_typeFactory);
    visitor.append(nativeScriptRuntime->_typeScriptOriginalExtendsFunction);
    visitor.append(nativeScriptRuntime->_ffiCallPrototype);
    visitor.append(nativeScriptRuntime->_objCMethodCallStructure);
    visitor.append(nativeScriptRuntime->_objCConstructorCallStructure);
    visitor.append(nativeScriptRuntime->_objCBlockCallStructure);
    visitor.append(nativeScriptRuntime->_ffiFunctionCallStructure);
    visitor.append(nativeScriptRuntime->_objCBlockCallbackStructure);
    visitor.append(nativeScriptRuntime->_objCMethodCallbackStructure);
    visitor.append(nativeScriptRuntime->_ffiFunctionCallbackStructure);
    visitor.append(nativeScriptRuntime->_recordFieldGetterStructure);
    visitor.append(nativeScriptRuntime->_recordFieldSetterStructure);
    visitor.append(nativeScriptRuntime->_unmanagedInstanceStructure);
    visitor.append(nativeScriptRuntime->_weakRefConstructorStructure);
    visitor.append(nativeScriptRuntime->_weakRefPrototypeStructure);
    visitor.append(nativeScriptRuntime->_weakRefInstanceStructure);
    visitor.append(nativeScriptRuntime->_fastEnumerationIteratorStructure);
}

/// This method is called whenever a property on the NativeScriptRuntime JavaScript object is accessed for the first time.
/// It is called once for each property and cached by JSC, i.e. it is never called again for the same property.
bool NativeScriptRuntime::getOwnPropertySlot(JSObject* object, ExecState* execState, PropertyName propertyName, PropertySlot& propertySlot) {
    if (Base::getOwnPropertySlot(object, execState, propertyName, propertySlot)) {
        return true;
    }

    NativeScriptRuntime* runtime = jsCast<NativeScriptRuntime*>(object);

    JSC::JSGlobalObject* globalObject = execState->lexicalGlobalObject();
    VM& vm = execState->vm();

    if (propertyName == runtime->_interopIdentifier) {
        propertySlot.setValue(object, static_cast<unsigned>(PropertyAttribute::DontEnum | PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly), runtime->interop());
        return true;
    }

    StringImpl* symbolName = propertyName.publicName();
    if (symbolName == nullptr)
        return false;

    const Meta* symbolMeta = Metadata::MetaFile::instance()->globalTable()->findMeta(symbolName);
    if (symbolMeta == nullptr)
        return false;

    JSValue symbolWrapper;

    switch (symbolMeta->type()) {
    case Interface: {
        Class klass = objc_getClass(symbolMeta->name());
        if (!klass) {
            SymbolLoader::instance().ensureModule(symbolMeta->topLevelModule());
            klass = objc_getClass(symbolMeta->name());
        }

        if (klass) {
            symbolWrapper = runtime->_typeFactory.get()->getObjCNativeConstructor(globalObject, symbolMeta->jsName());
            runtime->_objCConstructors.insert({ klass, Strong<ObjCConstructorBase>(vm, jsCast<ObjCConstructorBase*>(symbolWrapper)) });
        }
        break;
    }
    case ProtocolType: {
        Protocol* aProtocol = objc_getProtocol(symbolMeta->name());
        if (!aProtocol) {
            SymbolLoader::instance().ensureModule(symbolMeta->topLevelModule());
            aProtocol = objc_getProtocol(symbolMeta->name());
        }

        symbolWrapper = createProtocolWrapper(globalObject, static_cast<const ProtocolMeta*>(symbolMeta), aProtocol);
        if (aProtocol) {
            runtime->_objCProtocolWrappers.insert({ aProtocol, Strong<ObjCProtocolWrapper>(vm, jsCast<ObjCProtocolWrapper*>(symbolWrapper)) });
        }

        break;
    }
    case Union: {
        //        symbolWrapper = globalObject->typeFactory()->createOrGetUnionConstructor(globalObject, symbolName);
        break;
    }
    case Struct: {
        symbolWrapper = runtime->typeFactory()->getStructConstructor(globalObject, symbolName);
        break;
    }
    case MetaType::Function: {
        void* functionSymbol = SymbolLoader::instance().loadFunctionSymbol(symbolMeta->topLevelModule(), symbolMeta->name());
        if (functionSymbol) {
            const FunctionMeta* functionMeta = static_cast<const FunctionMeta*>(symbolMeta);
            const Metadata::TypeEncoding* encodingPtr = functionMeta->encodings()->first();
            JSCell* returnType = runtime->typeFactory()->parseType(globalObject, encodingPtr, false);
            const WTF::Vector<JSCell*> parametersTypes = runtime->typeFactory()->parseTypes(globalObject, encodingPtr, (int)functionMeta->encodings()->count - 1, false);

            if (functionMeta->returnsUnmanaged()) {
                JSC::Structure* unmanagedStructure = UnmanagedType::createStructure(vm, globalObject, jsNull());
                returnType = UnmanagedType::create(vm, returnType, unmanagedStructure);
            }

            symbolWrapper = FFIFunctionCall::create(vm, runtime->ffiFunctionCallStructure(), functionSymbol, functionMeta->jsName(), returnType, parametersTypes, functionMeta->ownsReturnedCocoaObject());
        }
        break;
    }
    case Var: {
        const VarMeta* varMeta = static_cast<const VarMeta*>(symbolMeta);
        void* varSymbol = SymbolLoader::instance().loadDataSymbol(varMeta->topLevelModule(), varMeta->name());
        if (varSymbol) {
            const Metadata::TypeEncoding* encoding = varMeta->encoding();
            JSCell* symbolType = runtime->typeFactory()->parseType(globalObject, encoding, false);
            symbolWrapper = getFFITypeMethodTable(vm, symbolType).read(execState, varSymbol, symbolType);
        }
        break;
    }
    case JsCode: {
        WTF::String source = WTF::String(static_cast<const JsCodeMeta*>(symbolMeta)->jsCode());
        symbolWrapper = evaluate(execState, makeSource(source, SourceOrigin()));
        break;
    }
    default: {
        break;
    }
    }

    if (!symbolWrapper) {
        WTF::String errorMessage = WTF::String::format("Metadata for \"%s.%s\" found but symbol not available at runtime.",
                                                       symbolMeta->topLevelModule()->getName(), symbolMeta->name(), symbolMeta->name());
        JSC::VM& vm = execState->vm();
        auto scope = DECLARE_THROW_SCOPE(vm);

        throwVMError(execState, scope, createReferenceError(execState, errorMessage));
        propertySlot.setValue(object, static_cast<unsigned>(PropertyAttribute::None), jsUndefined());
        return true;
    }

    object->putDirectWithoutTransition(vm, propertyName, symbolWrapper);
    propertySlot.setValue(object, static_cast<unsigned>(PropertyAttribute::None), symbolWrapper);
    return true;
}

#ifdef DEBUG
// There are more then 10000+ global object properties. When the debugger is attached,
// it calls this method on every breakpoint/step-in, which is *really* slow.
// On devices with not enough free memory, it even crashes the running application.
//
// This method is used only for testing now.
// It materializes all Objective-C classes and their methods and their parameter types.
//
// Once we start grouping declarations by modules, this can be safely restored.
void NativeScriptRuntime::getOwnPropertyNames(JSObject* object, ExecState* execState, PropertyNameArray& propertyNames, EnumerationMode enumerationMode) {
    if (!execState->lexicalGlobalObject()->hasDebugger()) {
        const GlobalTable* globalTable = MetaFile::instance()->globalTable();
        for (const Meta* meta : *globalTable) {
            if (meta->isAvailable()) {
                propertyNames.add(Identifier::fromString(execState, meta->jsName()));
            }
        }
    }

    Base::getOwnPropertyNames(object, execState, propertyNames, enumerationMode);
}
#endif

ObjCConstructorBase* NativeScriptRuntime::constructorFor(Class klass, Class fallback) {
    ASSERT(klass);

    auto kvp = this->_objCConstructors.find(klass);
    if (kvp != this->_objCConstructors.end()) {
        return kvp->second.get();
    }

    const Meta* meta = MetaFile::instance()->globalTable()->findMeta(class_getName(klass));
    while (!(meta && meta->type() == MetaType::Interface)) {
        klass = class_getSuperclass(klass);
        meta = MetaFile::instance()->globalTable()->findMeta(class_getName(klass));
    }

    if (klass == [NSObject class] && fallback) {
        return constructorFor(fallback);
    }

    kvp = this->_objCConstructors.find(klass);
    if (kvp != this->_objCConstructors.end()) {
        return kvp->second.get();
    }

    JSGlobalObject* globalObject = this->globalObject();
    ObjCConstructorNative* constructor = this->_typeFactory.get()->getObjCNativeConstructor(globalObject, meta->jsName());
    this->_objCConstructors.insert({ klass, Strong<ObjCConstructorBase>(globalObject->vm(), constructor) });
    this->putDirect(globalObject->vm(), Identifier::fromString(globalObject->globalExec(), class_getName(klass)), constructor);
    return constructor;
}

ObjCProtocolWrapper* NativeScriptRuntime::protocolWrapperFor(Protocol* aProtocol) {
    ASSERT(aProtocol);

    auto kvp = this->_objCProtocolWrappers.find(aProtocol);
    if (kvp != this->_objCProtocolWrappers.end()) {
        return kvp->second.get();
    }

    CString protocolName = protocol_getName(aProtocol);
    const Meta* meta = MetaFile::instance()->globalTable()->findMeta(protocolName.data());
    if (meta && meta->type() != MetaType::ProtocolType) {
        WTF::String newProtocolname = WTF::String::format("%sProtocol", protocolName.data());

        size_t protocolIndex = 2;
        while (objc_getProtocol(newProtocolname.utf8().data())) {
            newProtocolname = WTF::String::format("%sProtocol%d", protocolName.data(), protocolIndex++);
        }

        meta = MetaFile::instance()->globalTable()->findMeta(newProtocolname.utf8().data());
    }
    ASSERT(meta && meta->type() == MetaType::ProtocolType);

    JSGlobalObject* globalObject = this->globalObject();
    ObjCProtocolWrapper* protocolWrapper = createProtocolWrapper(globalObject, static_cast<const ProtocolMeta*>(meta), aProtocol);

    this->_objCProtocolWrappers.insert({ aProtocol, Strong<ObjCProtocolWrapper>(globalObject->vm(), protocolWrapper) });
    this->putDirectWithoutTransition(globalObject->vm(), Identifier::fromString(globalObject->globalExec(), meta->jsName()), protocolWrapper, PropertyAttribute::DontDelete | PropertyAttribute::ReadOnly);

    return protocolWrapper;
}

WTF::String NativeScriptRuntime::defaultLanguage() {
    return "en";
}
}
