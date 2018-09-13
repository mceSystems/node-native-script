//
//  JSStringUtils.h
//  NativeScript
//

#include "JSStringUtils.h"

// StringWrapperCFAllocator was taken from WTF's wtf/text/cf/StringImplCF.cpp
#include <CoreFoundation/CoreFoundation.h>
#include <wtf/MainThread.h>
#include <wtf/RetainPtr.h>
#include <wtf/Threading.h>

namespace StringWrapperCFAllocator {

    static StringImpl* currentString;

    static const void* retain(const void* info)
    {
        return info;
    }

    NO_RETURN_DUE_TO_ASSERT
    static void release(const void*)
    {
        ASSERT_NOT_REACHED();
    }

    static CFStringRef copyDescription(const void*)
    {
        return CFSTR("WTF::String-based allocator");
    }

    static void* allocate(CFIndex size, CFOptionFlags, void*)
    {
        StringImpl* underlyingString = 0;
        if (isMainThread()) {
            underlyingString = currentString;
            if (underlyingString) {
                currentString = 0;
                underlyingString->ref(); // Balanced by call to deref in deallocate below.
            }
        }
        StringImpl** header = static_cast<StringImpl**>(fastMalloc(sizeof(StringImpl*) + size));
        *header = underlyingString;
        return header + 1;
    }

    static void* reallocate(void* pointer, CFIndex newSize, CFOptionFlags, void*)
    {
        size_t newAllocationSize = sizeof(StringImpl*) + newSize;
        StringImpl** header = static_cast<StringImpl**>(pointer) - 1;
        ASSERT(!*header);
        header = static_cast<StringImpl**>(fastRealloc(header, newAllocationSize));
        return header + 1;
    }

    static void deallocate(void* pointer, void*)
    {
        StringImpl** header = static_cast<StringImpl**>(pointer) - 1;
        StringImpl* underlyingString = *header;
        if (!underlyingString)
            fastFree(header);
        else {
            if (isMainThread()) {
                underlyingString->deref(); // Balanced by call to ref in allocate above.
                fastFree(header);
                return;
            }

            callOnMainThread([header] {
                StringImpl* underlyingString = *header;
                ASSERT(underlyingString);
                underlyingString->deref(); // Balanced by call to ref in allocate above.
                fastFree(header);
            });
        }
    }

    static CFIndex preferredSize(CFIndex size, CFOptionFlags, void*)
    {
        // FIXME: If FastMalloc provided a "good size" callback, we'd want to use it here.
        // Note that this optimization would help performance for strings created with the
        // allocator that are mutable, and those typically are only created by callers who
        // make a new string using the old string's allocator, such as some of the call
        // sites in CFURL.
        return size;
    }

    static CFAllocatorRef create()
    {
        CFAllocatorContext context = { 0, 0, retain, release, copyDescription, allocate, reallocate, deallocate, preferredSize };
        return CFAllocatorCreate(0, &context);
    }

    static CFAllocatorRef allocator()
    {
        static CFAllocatorRef allocator = create();
        return allocator;
    }

}

namespace NativeScript {

// Based on WTF's String::String (wtf/text/cf/StringCF.cpp)
WTF::String CFStringToWTFString(CFStringRef str) {
    if (!str) {
        return WTF::emptyString();
    }

    CFIndex size = CFStringGetLength(str);
    if (size == 0) {
        return WTF::emptyString();
    }

    WTF::Vector<LChar, 1024> lcharBuffer(size);
    CFIndex usedBufLen;
    CFIndex convertedsize = CFStringGetBytes(str, CFRangeMake(0, size), kCFStringEncodingISOLatin1, 0, false, lcharBuffer.data(), size, &usedBufLen);
    if ((convertedsize == size) && (usedBufLen == size)) {
        return WTF::String(lcharBuffer.data(), size);
    }

    WTF::Vector<UChar, 1024> buffer(size);
    CFStringGetCharacters(str, CFRangeMake(0, size), (UniChar*)buffer.data());
    return WTF::String(buffer.data(), size);
}

// Based on WTF's String::createCFString (wtf/text/cf/StringCF.cpp) and StringImpl::createCFString (wtf/text/cf/StringImplCF.cpp)
RetainPtr<CFStringRef> WTFStringToCFString(const WTF::String& str)
{
    if (str.isEmpty()) {
        return CFSTR("");
    }

    unsigned int length = str.length();

    if (!length || !isMainThread()) {
        if (str.is8Bit())
            return adoptCF(CFStringCreateWithBytes(0, reinterpret_cast<const UInt8*>(str.characters8()), length, kCFStringEncodingISOLatin1, false));
        return adoptCF(CFStringCreateWithCharacters(0, reinterpret_cast<const UniChar*>(str.characters16()), length));
    }
    CFAllocatorRef allocator = StringWrapperCFAllocator::allocator();

    // Put pointer to the StringImpl in a global so the allocator can store it with the CFString.
    ASSERT(!StringWrapperCFAllocator::currentString);
    StringWrapperCFAllocator::currentString = str.impl();

    CFStringRef string;
    if (str.is8Bit())
        string = CFStringCreateWithBytesNoCopy(allocator, reinterpret_cast<const UInt8*>(str.characters8()), length, kCFStringEncodingISOLatin1, false, kCFAllocatorNull);
    else
        string = CFStringCreateWithCharactersNoCopy(allocator, reinterpret_cast<const UniChar*>(str.characters16()), length, kCFAllocatorNull);
    // CoreFoundation might not have to allocate anything, we clear currentString in case we did not execute allocate().
    StringWrapperCFAllocator::currentString = 0;

    return adoptCF(string);
}

// See wtf's test/cocoa/StringImplCocoa.mm and bridgingAutorelease implementation in wtf/RetainPtr.h
NSString * WTFStringToNSString(const WTF::String& str)
{
    return CFBridgingRelease(WTFStringToCFString(str).leakRef());
}

} // namespace NativeScript
