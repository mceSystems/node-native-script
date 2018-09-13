//
//  NativeScriptRuntime.h
//  NativeScript
//
//  Created by Yavor Georgiev on 14.07.14.
//  Copyright (c) 2014 г. Telerik. All rights reserved.
//

#ifndef __NativeScript__NativeScriptRuntime__
#define __NativeScript__NativeScriptRuntime__

#include "RuntimeLock.h"
#include <JavaScriptCore/JSDestructibleObject.h>
#include <JavaScriptCore/JSGlobalObject.h>
#include <JavaScriptCore/Strong.h>
#include <JavaScriptCore/Weak.h>
#include <list>
#include <map>
#include <objc/runtime.h>
#include <wtf/Deque.h>

struct uv_loop_s;
typedef struct uv_loop_s uv_loop_t;

namespace NativeScript {
class ObjCConstructorBase;
class ObjCProtocolWrapper;
class RecordConstructor;
class Interop;
class TypeFactory;
class ObjCWrapperObject;
class FFICallPrototype;
class ReleasePoolBase;

class NativeScriptRuntime : public JSC::JSDestructibleObject {
public:
    typedef JSC::JSDestructibleObject Base;

    typedef void (*UncaughtErrorHandler)(JSC::JSValue error);

    static const unsigned StructureFlags = Base::StructureFlags | JSC::OverridesGetOwnPropertySlot;

    static NativeScriptRuntime* create(JSC::VM& vm, 
                                       JSC::JSGlobalObject* globalObject, 
                                       JSC::Structure* structure, 
                                       UncaughtErrorHandler uncaughtErrorHandler, 
                                       uv_loop_t * eventLoop,
                                       RuntimeLock::Hooks * runtimeLockHooks) {
        NativeScriptRuntime* object = new (NotNull, JSC::allocateCell<NativeScriptRuntime>(vm.heap)) NativeScriptRuntime(vm, 
                                                                                                                         structure, 
                                                                                                                         uncaughtErrorHandler, 
                                                                                                                         eventLoop, 
                                                                                                                         runtimeLockHooks);
        object->finishCreation(vm, globalObject);
        return object;
    }

    DECLARE_INFO;

    static JSC::Structure* createStructure(JSC::VM& vm, JSC::JSGlobalObject* globalObject, JSC::JSValue prototype) {
        return JSC::Structure::create(vm, globalObject, prototype, JSC::TypeInfo(JSC::ObjectType, StructureFlags), info());
    }

    static bool getOwnPropertySlot(JSC::JSObject* object, JSC::ExecState* execState, JSC::PropertyName propertyName, JSC::PropertySlot& propertySlot);

#ifdef DEBUG
    static void getOwnPropertyNames(JSC::JSObject* object, JSC::ExecState* execState, JSC::PropertyNameArray& propertyNames, JSC::EnumerationMode enumerationMode);
#endif

    static void visitChildren(JSC::JSCell* cell, JSC::SlotVisitor& visitor);

    static NativeScriptRuntime * getRuntime(JSC::ExecState*) {
        return s_runtimeInstance.get();
    }
    static NativeScriptRuntime * getRuntime(JSC::JSGlobalObject*) {
        return s_runtimeInstance.get();
    }
    static NativeScriptRuntime * getRuntime(JSC::VM*) {
        return s_runtimeInstance.get();
    }

    RuntimeLock * lock() { return &_lock; }

    FFICallPrototype* ffiCallPrototype() const {
        return this->_ffiCallPrototype.get();
    }

    JSC::Structure* objCMethodCallStructure() const {
        return this->_objCMethodCallStructure.get();
    }

    JSC::Structure* objCConstructorCallStructure() const {
        return this->_objCConstructorCallStructure.get();
    }

    JSC::Structure* objCBlockCallStructure() const {
        return this->_objCBlockCallStructure.get();
    }

    JSC::Structure* ffiFunctionCallStructure() const {
        return this->_ffiFunctionCallStructure.get();
    }

    JSC::Structure* objCBlockCallbackStructure() const {
        return this->_objCBlockCallbackStructure.get();
    }

    JSC::Structure* objCMethodCallbackStructure() const {
        return this->_objCMethodCallbackStructure.get();
    }

    JSC::Structure* ffiFunctionCallbackStructure() const {
        return this->_ffiFunctionCallbackStructure.get();
    }

    JSC::Structure* recordFieldGetterStructure() const {
        return this->_recordFieldGetterStructure.get();
    }

    JSC::Structure* recordFieldSetterStructure() const {
        return this->_recordFieldSetterStructure.get();
    }

    Interop* interop() const {
        return this->_interop.get();
    }

    ObjCConstructorBase* constructorFor(Class klass, Class fallback = Nil);

    ObjCProtocolWrapper* protocolWrapperFor(Protocol* aProtocol);

    JSC::Structure* weakRefConstructorStructure() const {
        return this->_weakRefConstructorStructure.get();
    }

    JSC::Structure* weakRefPrototypeStructure() const {
        return this->_weakRefPrototypeStructure.get();
    }

    JSC::Structure* weakRefInstanceStructure() const {
        return this->_weakRefInstanceStructure.get();
    }

    JSC::Structure* unmanagedInstanceStructure() const {
        return this->_unmanagedInstanceStructure.get();
    }

    JSC::JSFunction* typeScriptOriginalExtendsFunction() const {
        return this->_typeScriptOriginalExtendsFunction.get();
    }

    TypeFactory* typeFactory() const {
        return _typeFactory.get();
    }

    JSC::Structure* fastEnumerationIteratorStructure() const {
        return this->_fastEnumerationIteratorStructure.get();
    }

    WTF::Deque<std::map<std::string, std::unique_ptr<ReleasePoolBase>>>& releasePools() {
        return this->_releasePools;
    }

    JSC::WeakGCMap<id, JSC::JSObject> * objectMap() const {
        return this->_objectMap.get();
    }

    // TODO: Move out of NativeSciprtRuntime? This is here since initially the spaces where stored by the NativeScriptRuntime instance
    inline JSC::IsoSubspace * ffiFunctionCallSpace() { return &((VMData *)(vm()->clientData))->_ffiFunctionCallSpace; }
    inline JSC::IsoSubspace * functionReferenceInstanceSpace() { return &((VMData *)(vm()->clientData))->_functionReferenceInstanceSpace; }
    inline JSC::IsoSubspace * nsErrorWrapperConstructorSpace() { return &((VMData *)(vm()->clientData))->_nsErrorWrapperConstructorSpace; }
    inline JSC::IsoSubspace * objCBlockCallSpace() { return &((VMData *)(vm()->clientData))->_objCBlockCallSpace; }
    inline JSC::IsoSubspace * objCConstructorCallSpace() { return &((VMData *)(vm()->clientData))->_objCConstructorCallSpace; }
    inline JSC::IsoSubspace * objCConstructorDerivedSpace() { return &((VMData *)(vm()->clientData))->_objCConstructorDerivedSpace; }
    inline JSC::IsoSubspace * objCConstructorNativeSpace() { return &((VMData *)(vm()->clientData))->_objCConstructorNativeSpace; }
    inline JSC::IsoSubspace * objCMethodCallSpace() { return &((VMData *)(vm()->clientData))->_objCMethodCallSpace; }
    inline JSC::IsoSubspace * pointerConstructorSpace() { return &((VMData *)(vm()->clientData))->_pointerConstructorSpace; }
    inline JSC::IsoSubspace * recordConstructorSpace() { return &((VMData *)(vm()->clientData))->_recordConstructorSpace; }
    inline JSC::IsoSubspace * recordProtoFieldGetterSetterSpace() { return &((VMData *)(vm()->clientData))->_recordProtoFieldGetterSetterSpace; }

    void callUncaughtErrorHandler(JSC::JSValue error) const {
        if (_uncaughtErrorHandler) {
            _uncaughtErrorHandler(error);
        }
    }

protected:
    static JSC::EncodedJSValue JSC_HOST_CALL commonJSRequire(JSC::ExecState*);

    NativeScriptRuntime(JSC::VM& vm, 
                        JSC::Structure* structure, 
                        UncaughtErrorHandler uncaughtNativeScriptErrorHandler, 
                        uv_loop_t * eventLoop, 
                        RuntimeLock::Hooks * runtimeLockHooks);

    ~NativeScriptRuntime();

    void finishCreation(JSC::VM& vm, JSC::JSGlobalObject* globalObject);

private:
    /* We can't store the IsoSubspaces in the NativeScriptRuntime instance, since 
     * it would be destructed before the VM, causing VM::~VM to crash in heap.lastChanceToFinalize 
     * (since the the space is added to the heap but doesn't seem to be removed if it's destructed).
     * So, we'll hold all IsoSubspaces in a struct we'll hold in the vm's clientData, intended for 
     * embedders use, and not used by jscshim. The vm's destructor will free it. */
    struct VMData : public JSC::VM::ClientData
    {
        JSC::IsoSubspace _ffiFunctionCallSpace;
        JSC::IsoSubspace _functionReferenceInstanceSpace;
        JSC::IsoSubspace _nsErrorWrapperConstructorSpace;
        JSC::IsoSubspace _objCBlockCallSpace;
        JSC::IsoSubspace _objCConstructorCallSpace;
        JSC::IsoSubspace _objCConstructorDerivedSpace;
        JSC::IsoSubspace _objCConstructorNativeSpace;
        JSC::IsoSubspace _objCMethodCallSpace;
        JSC::IsoSubspace _pointerConstructorSpace;
        JSC::IsoSubspace _recordConstructorSpace;
        JSC::IsoSubspace _recordProtoFieldGetterSetterSpace;

        VMData(JSC::VM& vm);
    };

    friend class ObjCClassBuilder;

    static void destroy(JSC::JSCell* cell) {
        static_cast<NativeScriptRuntime*>(cell)->~NativeScriptRuntime();
    }

    static WTF::String defaultLanguage();

    RuntimeLock _lock;

    JSC::WriteBarrier<FFICallPrototype> _ffiCallPrototype;
    JSC::WriteBarrier<JSC::Structure> _objCMethodCallStructure;
    JSC::WriteBarrier<JSC::Structure> _objCConstructorCallStructure;
    JSC::WriteBarrier<JSC::Structure> _objCBlockCallStructure;
    JSC::WriteBarrier<JSC::Structure> _ffiFunctionCallStructure;

    JSC::WriteBarrier<JSC::Structure> _objCBlockCallbackStructure;
    JSC::WriteBarrier<JSC::Structure> _objCMethodCallbackStructure;
    JSC::WriteBarrier<JSC::Structure> _ffiFunctionCallbackStructure;

    JSC::WriteBarrier<JSC::Structure> _recordFieldGetterStructure;
    JSC::WriteBarrier<JSC::Structure> _recordFieldSetterStructure;

    JSC::WriteBarrier<JSC::Structure> _fastEnumerationIteratorStructure;

    JSC::WriteBarrier<TypeFactory> _typeFactory;

    JSC::Identifier _interopIdentifier;
    JSC::WriteBarrier<Interop> _interop;

    JSC::WriteBarrier<JSC::JSFunction> _typeScriptOriginalExtendsFunction;

    JSC::WriteBarrier<JSC::Structure> _weakRefConstructorStructure;
    JSC::WriteBarrier<JSC::Structure> _weakRefPrototypeStructure;
    JSC::WriteBarrier<JSC::Structure> _weakRefInstanceStructure;

    JSC::WriteBarrier<JSC::Structure> _unmanagedInstanceStructure;

    std::map<Class, JSC::Strong<ObjCConstructorBase>> _objCConstructors;

    std::map<const Protocol*, JSC::Strong<ObjCProtocolWrapper>> _objCProtocolWrappers;

    WTF::Deque<std::map<std::string, std::unique_ptr<ReleasePoolBase>>> _releasePools;

    std::unique_ptr<JSC::WeakGCMap<id, JSC::JSObject>> _objectMap;

    static JSC::Strong<NativeScriptRuntime> s_runtimeInstance;

    UncaughtErrorHandler _uncaughtErrorHandler;
};
} // namespace NativeScript

#endif /* defined(__NativeScript__NativeScriptRuntime__) */
