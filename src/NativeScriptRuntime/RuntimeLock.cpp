//
//  RuntimeLock.cpp
//  NativeScript
//
//  Copyright (c) 2018 mce Sys Ltd. All rights reserved.
//

#include "jsc-includes.h"
#include "RuntimeLock.h"
#include "NativeScriptRuntime.h"

#include <JavaScriptCore/JSLock.h>
#include <wtf/Threading.h>
#include <uv.h>

namespace NativeScript {

RuntimeLock::RuntimeLock(JSC::VM * vm, uv_loop_t * eventLoop, Hooks * hooks) :
    _vm(vm),
    m_owner(nullptr),
    m_recursionCount(0)
{
    if (hooks) {
        _hooks = *hooks;
    } else {
        _hooks = { nullptr, nullptr, nullptr };
    }

    _async = std::make_unique<uv_async_t>();
    uv_async_init(eventLoop, _async.get(), asyncCallback);
    _async->data = this;
}

RuntimeLock::~RuntimeLock() {
    uv_close(reinterpret_cast<uv_handle_t*>(_async.get()), nullptr);
}

void RuntimeLock::lock() {
    Thread& me = Thread::current();
    if (&me == m_owner) {
        m_recursionCount++;
        return;
    }

    _lock.lock();
    m_owner = &me;
    m_recursionCount = 1;

    _asyncCallbackLock.lock();
    uv_async_send(_async.get());
    _vm->apiLock().lock();

    if (_hooks.lockedHook) {
        _hooks.lockedHook(_hooks.context);
    }
}

void RuntimeLock::unlock() {
    if (--m_recursionCount) {
        return;
    }
    m_owner = nullptr;

    _vm->apiLock().unlock();
    _asyncCallbackLock.unlock();
    
    _lock.unlock();

    if (_hooks.unlockedHook) {
        _hooks.unlockedHook(_hooks.context);
    }
}

void RuntimeLock::asyncCallback(uv_async_t * asyncHandle)
{
    RuntimeLock * runtimeLock = reinterpret_cast<RuntimeLock *>(asyncHandle->data);

    {
        JSC::JSLock::DropAllLocks dropAllLocks(runtimeLock->_vm);
        runtimeLock->_asyncCallbackLock.lock();
    }

    // Must be done after dropAllLocks was destroyed and we've acquired the vm's lock again
    runtimeLock->_asyncCallbackLock.unlock();
}

RuntimeLockHolder::RuntimeLockHolder(NativeScriptRuntime * runtime) :
    _runtime(runtime) {
    runtime->lock()->lock();
}

RuntimeLockHolder::RuntimeLockHolder(JSC::VM * vm) : RuntimeLockHolder(NativeScriptRuntime::getRuntime(vm)) {
}

RuntimeLockHolder::RuntimeLockHolder(JSC::VM& vm) : RuntimeLockHolder(NativeScriptRuntime::getRuntime(&vm)) {
}

RuntimeLockHolder::~RuntimeLockHolder() {
    _runtime->lock()->unlock();
}

} // namespace NativeScript