//
//  RuntimeLock.h
//  NativeScript
//
//  Copyright (c) 2018 mce Sys Ltd. All rights reserved.
//

#ifndef __NativeScript__RuntimeLock__
#define __NativeScript__RuntimeLock__

#include <memory>
#include <wtf/Lock.h>
#include <wtf/Threading.h>

/* Use forward declarations in order to avoid including libuv and JSC (since our header will be included
 * pretty much everywhere) */
struct uv_loop_s;
struct uv_async_s;
typedef struct uv_loop_s uv_loop_t;
typedef struct uv_async_s uv_async_t;

namespace JSC { 
    class VM;
}

namespace NativeScript {

class NativeScriptRuntime;

/* Originally, NativeScript used JSC::JSLockHolder to lock a VM (acquire it's "api lock", which is a JSC::JSLock instance) 
 * when needed (mainly in objective c blocks\callbacks). Generally, this is what WebKit users should do.
 * For node-native-script, we have a few problems with JSLock and with being called from another thread:
 * - Currently, jscshim holds the api lock, constantly, meaning we'll dead lock. Even when\if
 *   jscshim will properly release the lock when it's not needed, node locks the isolate on the main thread
 *   using v8::Locker (see the "Start" function in node.cc).
 * - The new thread won't have an "entered" v8 Isolate, whish is necessary for native code executing on that thread
 *   (or else calls to 8::Isolate::GetCurrent() will crash).
 * - Code running on the new thread might call libuv functions (either directly on internall by node),
 *   which aren't thread safe, and according to various discussions shouldn't be called from other threads. 
 *
 * It seems that we have two possible solutions:
 * - Use libuv's async callbacks (uv_async_*) to run the needed pieces of code on node's event loop thread.
 *   This sounds pretty straightforward, but will require modifying\refactoring every piece of code in
 *   NativeScript guarded by JSC::JSLock into a separate function.
 * - Temporarily block\stop libuv's event loop (thread), and "steal" the JSC::JSLock held by that thread, while
 *   we're executing code in another thread. Blocking the event loop can be done using an async callback blocking 
 *   the event loop (by holding a mutex, for example). Stealing the JSC::JSLock from another thread is supoprted 
 *   directly by JSC::JSLock, using JSC::JSLock::DropAllLocks. This has the advantage of just replacing 
 *   JSC::JSLockHolder instances with our own RuntimeLockHolder, and thats it. The downside of this solution
 *   is that our code will run from another thread, which might have consequences. In libuv for example, 
 *   there might be significance to which thread calls a function (see the last paragraph here for more information).
 *   This solution also doesn't solve the v8::Isolate problem mentioned above, as the new thread doesn't have an
 *   entered v8::Isolate.
 *
 *  For now, in order to avoid making more changes to NativeScript, we'll use the second solution:
 *  - A mutex (WTF::Lock) will serve as the RuntimeLock's actual lock.
 *  - To pause the event loop thread, we'll use uv_async_send to schedule a callback on the event
 *    loop's thread, which will use JSC::JSLock::DropAllLocks to release the vm's lock, while we'll grab it. 
 *    The callback will then wait for us to finish (by calling our "unlock") before aqcuring the locks again 
 *    (this is done by JSC::JSLock::DropAllLocks). A possible implementation for this is:
 *    - lock:
 *      - Acquire our internal lock
 *      - Schedule the async callback to be executed on the main thread
 *      - Acquire the vm lock (which will block until the callback drops the vm lock)
 *      - On the main thread, the callback could just create and instance of DropAllLocks. It's ctor will
 *        release jscshim's lock, releasing our RuntimeLock::lock, which was waiting on the lock.
 *        DropAllLocks' dtor will try to acquire the vm's lock back, thus blocking until RuntimeLock::unlock
 *        will release it.
 *    - To unlock, simply release the vm lock (letting the callback acquire it back and finish, "releasing" the 
 *      event loop) and release our internal lock.
 *    - We'll provide "hooks" (callbacks) for when the lock is locked\unlocked, allowing the callbacks to
 *      set a v8::Isolate on the new thread.
 *
 *    The above solution has a possible problem which is solved by using a second (internal) lock:
 *    Theoretically, after we've released the vm's lock and continue, another RuntimeLock instance
 *    (on our thread) could grab the lock, before the async callback (JSC::JSLock::DropAllLocks's dtor) 
 *    manage to acquire it back. Thus, we want our RuntimeLock::unlock to wait on the callback
 *    (at least until it acquired the vm lock).
 *
 * After I've implemented it, I've found this issue on github: https://github.com/joyent/libuv/issues/454,
 * which basically suggested the same idea. Accroding to one of the comments (made by one of libuv's
 * auth), this is problematic on Windows, where the's a significance to which thread makes a system call.
 * Since we only target iOS, it currently seem fine for us, at least until we find a better solution.
 */ 

// Recursive locking support is based on on WTF::RecursiveLockAdapter
class RuntimeLock {
public:
    struct Hooks {
        using HookCallback = void (*)(void * context);

        HookCallback lockedHook;
        HookCallback unlockedHook;
        void * context;
    };

    RuntimeLock(JSC::VM * vm, uv_loop_t * eventLoop, Hooks * hooks = nullptr);
    ~RuntimeLock();

    void lock();
    void unlock();

private:
    static void asyncCallback(uv_async_t * asyncHandle);
    
    std::unique_ptr<uv_async_t> _async;

    JSC::VM * _vm;
    WTF::Lock _lock;
    WTF::Lock _asyncCallbackLock;
    Hooks _hooks;

    Thread* m_owner; 
    unsigned m_recursionCount;
};

class RuntimeLockHolder {
public:
    RuntimeLockHolder(NativeScriptRuntime * runtime);
    RuntimeLockHolder(JSC::VM * vm);
    RuntimeLockHolder(JSC::VM& vm);
    ~RuntimeLockHolder();

private:
    NativeScriptRuntime * _runtime;
};

} // namespace NativeScript

#endif /* defined(__NativeScript__RuntimeLock__) */