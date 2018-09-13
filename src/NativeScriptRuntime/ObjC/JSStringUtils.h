//
//  JSStringUtils.h
//  NativeScript
//

#ifndef __NativeScript__JSStringUtils__
#define __NativeScript__JSStringUtils__

#include <wtf/text/WTFString.h>

namespace NativeScript {

WTF::String CFStringToWTFString(CFStringRef str);

RetainPtr<CFStringRef> WTFStringToCFString(const WTF::String& str);

NSString * WTFStringToNSString(const WTF::String& str);

} // namespace NativeScript

#endif /* defined(__NativeScript__JSStringUtils__) */