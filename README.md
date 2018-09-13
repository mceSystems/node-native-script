# node-native-script - NativeScript's iOS runtime as a node module
Access native iOS APIs from [node-jsc](https://github.com/mceSystems/node-jsc), directly from javascript.
For example:
```javascript
const ios = require("./node-native-script");

function readContacts() {
    const contactStore = new ios.CNContactStore();
    
    const keys = [ios.CNContactEmailAddressesKey, ios.CNContactPhoneNumbersKey, ios.CNContactFamilyNameKey, ios.CNContactGivenNameKey];
    const request = ios.CNContactFetchRequest.alloc().initWithKeysToFetch(keys);
    
    const contacts = [];
    contactStore.enumerateContactsWithFetchRequestErrorUsingBlock(request, null, (contact, stop) => {
        contacts.push({
            firstName: contact.givenName,
            lastName: contact.familyName,
            email: contact.emailAddresses.length > 0 ? contact.emailAddresses[0].value : null,
            phoneNumber: contact.phoneNumbers.length > 0 ? contact.phoneNumbers[0].value.stringValue : null
        });
    });

    return contacts;
}
```

Based on [NativeScript](https://www.nativescript.org)'s iOS Runtime.

**Note that while [NativeScript](https://www.nativescript.org)'s is a mature and tested framework, node-native-script is an early proof of concept, and is not ready for production use.**

## What is NativeScript and NativeScript's iOS Runtime?
*"NativeScript is an open-source framework for building cross-platform mobile apps for iOS and Android, created and maintained by Telerik"* ([NativeScript](https://www.nativescript.org)'s book). 
NativeScript apps are written in javascript (or TypeScript), while the framework allows developers to access the native platofrm's (Android and iOS) SDK\APIs directly from javascript, and to interface with custom native modules. On iOS this is done by the [NativeScript iOS Runtime](https://docs.nativescript.org/core-concepts/ios-runtime/Overview), which uses JavaScriptCore: *"In order to translate JavaScript code to the corresponding native APIs some kind of proxy mechanism is needed. This is exactly what the "Runtime" parts of NativeScript are responsible for. The iOS Runtime may be thought of as 'The Bridge' between the JavaScript and the iOS world"* (NativeScript's documentation).

## What is node-native-script? Why?
node-native-script is a stripped down version of NativeScript's iOS runtime, refactored as an node native extension. Targeting [node-jsc](https://github.com/mceSystems/node-jsc) (and using its JavaScriptCore engine), node-native-script allows javascript code running in node to access iOS (Objective C) APIs directly, without needing to write native code.

## How to build
### Prerequisites
* Local node.js and npm, for obtaining [NAN](https://github.com/nodejs/nan).
* A copy of [node-jsc](https://github.com/mceSystems/node-jsc). Either use github's "Download ZIP" feature, or use git (required git installed):
  ```
  git clone https://github.com/mceSystems/node-jsc
  ```
* A valid, configured, code signing identity. To view configured identities:
  ```
  security find-identity -v -p codesigning
  ```
  For more information, see ["inside-code-signing"](https://www.objc.io/issues/17-security/inside-code-signing/).

### Building
From the terminal, make build_ios.sh script executable (only needed once):
```
chmod +x build_ios.sh
```

Then use build_ios.sh to build and sign node-native-script:
```
./build_ios.sh <node-jsc source path> <code signing identity>
```

## Using node-native-script
After building node-native-script, simply copy it to the js directory in your node-jsc based app. You can omit the "src" and "script" folders, build_ios.sh and this README.md file.
See [NativeScript's iOS Runtime](https://docs.nativescript.org/core-concepts/ios-runtime/) documentation for more information about using the runtime, naming conventions, marshling, supported Objective-C features (like blocks), etc.

## Async Operations
Currently, async native calls, initiated by calling ios APIs (that usually receive a block\callback) aren't "registered" with node's event loop, thus node isn't aware of them. This means that node won't wait for them to finish, and might try to shutdown while an async operation hasn't finished. 
For now, if your code is using async API calls and you need to block node from shutting down, you can, for example, add:
```javascript
process.stdin.resume();
```
to your code.

## Major changes compared to NativeScript's original iOS runtime
* Instead of exposing all of the api in the global object, it's now exposed through an object (exported by this module). This is a major change, which was required since originally NativeScript could inherit from JSC::JSGlobalObject and provide a custom global object, which it can't as a node module.
* Stripped away:
  * VM initialization and management - not needed (done by node-jsc\jscshim)
  * Module loader - Not needed since we have node's
  * Debugging support (inspector) - Will be intergrated with node-jsc\jscshim
  * LiveSync
  * Workers - web workers support would be done through node-jsc
* WebKit:
  * Use node-jsc WebKit instead of an embedded one.
  * Updated to work with the newer WebKit version used by node-jsc
  * Replaced JSC::LockHolder with a custom locking solution for node-jsc. See src/NativeScriptRuntime/RuntimeLock.h for detailed information.
* Build using gyp instead of cmake

## Current Limitations
* Only 64bit builds are supported
* Only one VM (one v8::Isolate) is supported
* Metadata generation hasn't been intergrated yet, so a pre-generated one is currently provided