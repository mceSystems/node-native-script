{
  'targets': [
    {
      'target_name': 'libffi',
      'type': 'none',

      'direct_dependent_settings': {
        'include_dirs': ['src/libffi/build/Release-iphoneos/include/ffi'],
        'link_settings': {
          'libraries': ['<!(pwd)/src/libffi/build/Release-iphoneos/libffi.a']
        },
      },

      'actions': [
       {
        'action_name': 'libffi_build',
        'inputs': [
            # This doesn't cover all sources, but should be enough to trigger a rebuild on important code changes.
            # Note that this doesn't affect the build script, just gyp's ability to trigger this action if 
            # libffi is modified.
            'src/libffi/src/closures.c',
            'src/libffi/src/dlmalloc.c',
            'src/libffi/src/prep_cif.c',
            'src/libffi/src/raw_api.c',
            'src/libffi/src/types.c',

            'src/libffi/src/aarch64/ffi.c',
            'src/libffi/src/aarch64/ffitarget.h',
            'src/libffi/src/aarch64/internal.h',
            'src/libffi/src/aarch64/sysv.S',

        ],
        'outputs': [
            'src/libffi/build/Release-iphoneos/libffi.a',
            'src/libffi/build/Release-iphoneos/include/ffi.h',
            'src/libffi/build/Release-iphoneos/include/ffi_arm64.h',
            'src/libffi/build/Release-iphoneos/include/ffitarget.h',
            'src/libffi/build/Release-iphoneos/include/ffitarget_arm64.h',
        ],
        'action': ['./scripts/build_libffi.sh'],
       }
     ],
    },

    {
      'target_name': 'NativeScript_generate_js_headers',
      'type': 'none',
      'toolsets': ['host'],

      # Note the inputs and outputs order must match, in order to create the corrent input\ouput pairs
      'actions': [
       {
        'action_name': 'NativeScript_generate_js_headers',
        'inputs': [
            'src/NativeScriptRuntime/__extends.js',
            'src/NativeScriptRuntime/inlineFunctions.js'
        ],
        'outputs': [
            '<(SHARED_INTERMEDIATE_DIR)/__extends.h',
            '<(SHARED_INTERMEDIATE_DIR)/inlineFunctions.h',
        ],
        'action': ['bash', '-c', 'nativescript_js_inputs=(<@(_inputs)); nativescript_js_outputs=(<@(_outputs)); . ./scripts/generate_js_headers.sh'],
       }
     ],
    },

    {
      'target_name': 'NativeScript',

      'dependencies': [
        'libffi',
        'NativeScript_generate_js_headers#host',
      ],

      'include_dirs': [
        'src',
        'src/NativeScriptRuntime',
        'src/NativeScriptRuntime/Calling',
        'src/NativeScriptRuntime/Marshalling',
        'src/NativeScriptRuntime/Marshalling/FunctionReference',
        'src/NativeScriptRuntime/Marshalling/Fundamentals',
        'src/NativeScriptRuntime/Marshalling/Pointer',
        'src/NativeScriptRuntime/Marshalling/Record',
        'src/NativeScriptRuntime/Marshalling/Reference',
        'src/NativeScriptRuntime/Metadata',
        'src/NativeScriptRuntime/ObjC',
        'src/NativeScriptRuntime/ObjC/Block',
        'src/NativeScriptRuntime/ObjC/Constructor',
        'src/NativeScriptRuntime/ObjC/Enumeration',
        'src/NativeScriptRuntime/ObjC/Inheritance',
        'src/NativeScriptRuntime/ObjC/Unmanaged',
        'src/NativeScriptRuntime/Runtime',

        # For the headers generated by the NativeScript_generate_js_headers target above
        '<(SHARED_INTERMEDIATE_DIR)',

        # NAN
        "<!(node -e \"require('nan')\")",

        # Webkit
        '<(node_root_dir)/deps/jscshim/webkit/WebKitBuild/DerivedSources/ForwardingHeaders',
        '<(node_root_dir)/deps/jscshim/webkit/WebKitBuild/DerivedSources/ForwardingHeaders/JavaScriptCore',
        '<(node_root_dir)/deps/jscshim/webkit/Source/bmalloc',
        '<(node_root_dir)/deps/jscshim/webkit/WebKitBuild',
      ],

      'defines': [
        # Match the direct_dependent_settings section from jscshim's webkit.gyp, but without the
        # STATICALLY_LINKED_WITH_JavaScriptCore\STATICALLY_LINKED_WITH_WTF
        'HAVE_CONFIG_H=1',
        'BUILDING_WITH_CMAKE=1',
        'ENABLE_INSPECTOR_ALTERNATE_DISPATCHERS=0',
        'ENABLE_RESOURCE_USAGE=1',
        'BUILDING_JSCONLY__',
        'USE_FOUNDATION=1',
        'JSC_OBJC_API_ENABLED=0',

        # Match WTF's UCHAR_TYPE
        'UCHAR_TYPE=uint16_t',
      ],

      'xcode_settings': {
        'GCC_VERSION': 'com.apple.compilers.llvm.clang.1_0',
        'CLANG_CXX_LANGUAGE_STANDARD': 'gnu++17',
        'CLANG_CXX_LIBRARY': 'libc++',
      },

      # Taken from NativeScript's cmake files
      'cflags': [
        '-fno-exceptions',
        '-fno-rtti',
        '-fno-objc-arc',
        '-Werror',
        '-Wall',
        '-Wextra',
        '-Wcast-align',
        '-Wformat-security',
        '-Wmissing-format-attribute',
        '-Wpointer-arith',
        '-Wundef',
        '-Wwrite-strings',
        '-Wno-shorten-64-to-32',
        '-Wno-bool-conversion',
        '-Wno-unused-parameter',
        '-Wno-macro-redefined',
      ],
      'xcode_settings': {
        'OTHER_LDFLAGS': [
          '-Wl,-sectcreate,__DATA,__TNSMetadata,<!(pwd)/metadata/metadata-arm64.bin',
        ]
      },

      'sources': [ 
        'src/binding.cpp',
        'src/createNativeScriptRuntime.h',
        'src/createNativeScriptRuntime.mm',

        'src/NativeScriptRuntime/Calling/FFICache.cpp',
        'src/NativeScriptRuntime/Calling/FFICache.h',
        'src/NativeScriptRuntime/Calling/FFICall.cpp',
        'src/NativeScriptRuntime/Calling/FFICall.h',
        'src/NativeScriptRuntime/Calling/FFICallback.h',
        'src/NativeScriptRuntime/Calling/FFICallbackInlines.h',
        'src/NativeScriptRuntime/Calling/FFICallPrototype.cpp',
        'src/NativeScriptRuntime/Calling/FFICallPrototype.h',
        'src/NativeScriptRuntime/Calling/FFIFunctionCall.h',
        'src/NativeScriptRuntime/Calling/FFIFunctionCall.mm',
        'src/NativeScriptRuntime/Calling/FFIFunctionCallback.cpp',
        'src/NativeScriptRuntime/Calling/FFIFunctionCallback.h',
        'src/NativeScriptRuntime/Interop.h',
        'src/NativeScriptRuntime/Interop.mm',
        'src/NativeScriptRuntime/JSErrors.h',
        'src/NativeScriptRuntime/JSErrors.mm',
        'src/NativeScriptRuntime/JSWarnings.cpp',
        'src/NativeScriptRuntime/JSWarnings.h',
        'src/NativeScriptRuntime/Marshalling/FFISimpleType.cpp',
        'src/NativeScriptRuntime/Marshalling/FFISimpleType.h',
        'src/NativeScriptRuntime/Marshalling/FFIType.mm',
        'src/NativeScriptRuntime/Marshalling/FFIType.h',
        'src/NativeScriptRuntime/Marshalling/FunctionReference/FunctionReferenceConstructor.cpp',
        'src/NativeScriptRuntime/Marshalling/FunctionReference/FunctionReferenceConstructor.h',
        'src/NativeScriptRuntime/Marshalling/FunctionReference/FunctionReferenceInstance.cpp',
        'src/NativeScriptRuntime/Marshalling/FunctionReference/FunctionReferenceInstance.h',
        'src/NativeScriptRuntime/Marshalling/FunctionReference/FunctionReferenceTypeConstructor.mm',
        'src/NativeScriptRuntime/Marshalling/FunctionReference/FunctionReferenceTypeConstructor.h',
        'src/NativeScriptRuntime/Marshalling/FunctionReference/FunctionReferenceTypeInstance.cpp',
        'src/NativeScriptRuntime/Marshalling/FunctionReference/FunctionReferenceTypeInstance.h',
        'src/NativeScriptRuntime/Marshalling/Fundamentals/FFINumericTypes.h',
        'src/NativeScriptRuntime/Marshalling/Fundamentals/FFINumericTypes.mm',
        'src/NativeScriptRuntime/Marshalling/Fundamentals/FFIPrimitiveTypes.mm',
        'src/NativeScriptRuntime/Marshalling/Fundamentals/FFIPrimitiveTypes.h',
        'src/NativeScriptRuntime/Marshalling/Pointer/PointerConstructor.cpp',
        'src/NativeScriptRuntime/Marshalling/Pointer/PointerConstructor.h',
        'src/NativeScriptRuntime/Marshalling/Pointer/PointerInstance.cpp',
        'src/NativeScriptRuntime/Marshalling/Pointer/PointerInstance.h',
        'src/NativeScriptRuntime/Marshalling/Pointer/PointerPrototype.cpp',
        'src/NativeScriptRuntime/Marshalling/Pointer/PointerPrototype.h',
        'src/NativeScriptRuntime/Marshalling/Record/RecordConstructor.cpp',
        'src/NativeScriptRuntime/Marshalling/Record/RecordConstructor.h',
        'src/NativeScriptRuntime/Marshalling/Record/RecordField.cpp',
        'src/NativeScriptRuntime/Marshalling/Record/RecordField.h',
        'src/NativeScriptRuntime/Marshalling/Record/RecordInstance.cpp',
        'src/NativeScriptRuntime/Marshalling/Record/RecordInstance.h',
        'src/NativeScriptRuntime/Marshalling/Record/RecordPrototype.cpp',
        'src/NativeScriptRuntime/Marshalling/Record/RecordPrototype.h',
        'src/NativeScriptRuntime/Marshalling/Record/RecordPrototypeFunctions.cpp',
        'src/NativeScriptRuntime/Marshalling/Record/RecordPrototypeFunctions.h',
        'src/NativeScriptRuntime/Marshalling/Record/RecordType.h',
        'src/NativeScriptRuntime/Marshalling/Reference/ExtVectorTypeInstance.cpp',
        'src/NativeScriptRuntime/Marshalling/Reference/ExtVectorTypeInstance.h',
        'src/NativeScriptRuntime/Marshalling/Reference/IndexedRefInstance.cpp',
        'src/NativeScriptRuntime/Marshalling/Reference/IndexedRefInstance.h',
        'src/NativeScriptRuntime/Marshalling/Reference/IndexedRefPrototype.cpp',
        'src/NativeScriptRuntime/Marshalling/Reference/IndexedRefPrototype.h',
        'src/NativeScriptRuntime/Marshalling/Reference/IndexedRefTypeInstance.cpp',
        'src/NativeScriptRuntime/Marshalling/Reference/IndexedRefTypeInstance.h',
        'src/NativeScriptRuntime/Marshalling/Reference/ReferenceConstructor.cpp',
        'src/NativeScriptRuntime/Marshalling/Reference/ReferenceConstructor.h',
        'src/NativeScriptRuntime/Marshalling/Reference/ReferenceInstance.cpp',
        'src/NativeScriptRuntime/Marshalling/Reference/ReferenceInstance.h',
        'src/NativeScriptRuntime/Marshalling/Reference/ReferencePrototype.cpp',
        'src/NativeScriptRuntime/Marshalling/Reference/ReferencePrototype.h',
        'src/NativeScriptRuntime/Marshalling/Reference/ReferenceTypeConstructor.mm',
        'src/NativeScriptRuntime/Marshalling/Reference/ReferenceTypeConstructor.h',
        'src/NativeScriptRuntime/Marshalling/Reference/ReferenceTypeInstance.cpp',
        'src/NativeScriptRuntime/Marshalling/Reference/ReferenceTypeInstance.h',
        'src/NativeScriptRuntime/Metadata/Metadata.h',
        'src/NativeScriptRuntime/Metadata/Metadata.mm',
        'src/NativeScriptRuntime/NativeScript-Prefix.h',
        'src/NativeScriptRuntime/NativeScriptRuntime.h',
        'src/NativeScriptRuntime/NativeScriptRuntime.mm',
        'src/NativeScriptRuntime/ObjC/AllocatedPlaceholder.mm',
        'src/NativeScriptRuntime/ObjC/AllocatedPlaceholder.h',
        'src/NativeScriptRuntime/ObjC/Block/ObjCBlockCall.h',
        'src/NativeScriptRuntime/ObjC/Block/ObjCBlockCall.mm',
        'src/NativeScriptRuntime/ObjC/Block/ObjCBlockCallback.mm',
        'src/NativeScriptRuntime/ObjC/Block/ObjCBlockCallback.h',
        'src/NativeScriptRuntime/ObjC/Block/ObjCBlockType.h',
        'src/NativeScriptRuntime/ObjC/Block/ObjCBlockType.mm',
        'src/NativeScriptRuntime/ObjC/Block/ObjCBlockTypeConstructor.mm',
        'src/NativeScriptRuntime/ObjC/Block/ObjCBlockTypeConstructor.h',
        'src/NativeScriptRuntime/ObjC/Constructor/ObjCConstructorBase.h',
        'src/NativeScriptRuntime/ObjC/Constructor/ObjCConstructorBase.mm',
        'src/NativeScriptRuntime/ObjC/Constructor/ObjCConstructorCall.h',
        'src/NativeScriptRuntime/ObjC/Constructor/ObjCConstructorCall.mm',
        'src/NativeScriptRuntime/ObjC/Constructor/ObjCConstructorDerived.mm',
        'src/NativeScriptRuntime/ObjC/Constructor/ObjCConstructorDerived.h',
        'src/NativeScriptRuntime/ObjC/Constructor/ObjCConstructorNative.h',
        'src/NativeScriptRuntime/ObjC/Constructor/ObjCConstructorNative.mm',
        'src/NativeScriptRuntime/ObjC/Enumeration/ObjCFastEnumerationIterator.h',
        'src/NativeScriptRuntime/ObjC/Enumeration/ObjCFastEnumerationIterator.mm',
        'src/NativeScriptRuntime/ObjC/Enumeration/ObjCFastEnumerationIteratorPrototype.h',
        'src/NativeScriptRuntime/ObjC/Enumeration/ObjCFastEnumerationIteratorPrototype.mm',
        'src/NativeScriptRuntime/ObjC/Enumeration/TNSFastEnumerationAdapter.h',
        'src/NativeScriptRuntime/ObjC/Enumeration/TNSFastEnumerationAdapter.mm',
        'src/NativeScriptRuntime/ObjC/Inheritance/ObjCClassBuilder.h',
        'src/NativeScriptRuntime/ObjC/Inheritance/ObjCClassBuilder.mm',
        'src/NativeScriptRuntime/ObjC/Inheritance/ObjCExtend.h',
        'src/NativeScriptRuntime/ObjC/Inheritance/ObjCExtend.mm',
        'src/NativeScriptRuntime/ObjC/Inheritance/ObjCTypeScriptExtend.h',
        'src/NativeScriptRuntime/ObjC/Inheritance/ObjCTypeScriptExtend.mm',
        'src/NativeScriptRuntime/ObjC/JSStringUtils.h',
        'src/NativeScriptRuntime/ObjC/JSStringUtils.mm',
        'src/NativeScriptRuntime/ObjC/NSErrorWrapperConstructor.h',
        'src/NativeScriptRuntime/ObjC/NSErrorWrapperConstructor.mm',
        'src/NativeScriptRuntime/ObjC/ObjCMethodCall.h',
        'src/NativeScriptRuntime/ObjC/ObjCMethodCall.mm',
        'src/NativeScriptRuntime/ObjC/ObjCMethodCallback.h',
        'src/NativeScriptRuntime/ObjC/ObjCMethodCallback.mm',
        'src/NativeScriptRuntime/ObjC/ObjCPrimitiveTypes.h',
        'src/NativeScriptRuntime/ObjC/ObjCPrimitiveTypes.mm',
        'src/NativeScriptRuntime/ObjC/ObjCProtocolWrapper.h',
        'src/NativeScriptRuntime/ObjC/ObjCProtocolWrapper.mm',
        'src/NativeScriptRuntime/ObjC/ObjCPrototype.h',
        'src/NativeScriptRuntime/ObjC/ObjCPrototype.mm',
        'src/NativeScriptRuntime/ObjC/ObjCSuperObject.h',
        'src/NativeScriptRuntime/ObjC/ObjCSuperObject.mm',
        'src/NativeScriptRuntime/ObjC/ObjCTypes.h',
        'src/NativeScriptRuntime/ObjC/ObjCTypes.mm',
        'src/NativeScriptRuntime/ObjC/ObjCWrapperObject.h',
        'src/NativeScriptRuntime/ObjC/ObjCWrapperObject.mm',
        'src/NativeScriptRuntime/ObjC/TNSArrayAdapter.h',
        'src/NativeScriptRuntime/ObjC/TNSArrayAdapter.mm',
        'src/NativeScriptRuntime/ObjC/TNSDataAdapter.h',
        'src/NativeScriptRuntime/ObjC/TNSDataAdapter.mm',
        'src/NativeScriptRuntime/ObjC/TNSDictionaryAdapter.h',
        'src/NativeScriptRuntime/ObjC/TNSDictionaryAdapter.mm',
        'src/NativeScriptRuntime/ObjC/Unmanaged/UnmanagedInstance.cpp',
        'src/NativeScriptRuntime/ObjC/Unmanaged/UnmanagedInstance.h',
        'src/NativeScriptRuntime/ObjC/Unmanaged/UnmanagedPrototype.h',
        'src/NativeScriptRuntime/ObjC/Unmanaged/UnmanagedPrototype.mm',
        'src/NativeScriptRuntime/ObjC/Unmanaged/UnmanagedType.cpp',
        'src/NativeScriptRuntime/ObjC/Unmanaged/UnmanagedType.h',
        'src/NativeScriptRuntime/Runtime/JSWeakRefConstructor.cpp',
        'src/NativeScriptRuntime/Runtime/JSWeakRefConstructor.h',
        'src/NativeScriptRuntime/Runtime/JSWeakRefInstance.cpp',
        'src/NativeScriptRuntime/Runtime/JSWeakRefInstance.h',
        'src/NativeScriptRuntime/Runtime/JSWeakRefPrototype.cpp',
        'src/NativeScriptRuntime/Runtime/JSWeakRefPrototype.h',
        'src/NativeScriptRuntime/Runtime/ReleasePool.h',
        'src/NativeScriptRuntime/RuntimeLock.cpp',
        'src/NativeScriptRuntime/RuntimeLock.h',
        'src/NativeScriptRuntime/SymbolLoader.h',
        'src/NativeScriptRuntime/SymbolLoader.mm',
        'src/NativeScriptRuntime/TypeFactory.h',
        'src/NativeScriptRuntime/TypeFactory.mm',
        'src/NativeScriptRuntime/WeakHandleOwners.h'
      ]
    }
  ]
}
