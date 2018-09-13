//
//  TNSFastEnumerationAdapter.h
//  NativeScript
//
//  Created by Yavor Georgiev on 15.07.15.
//  Copyright (c) 2015 Telerik. All rights reserved.
//

#import <Foundation/NSEnumerator.h>

#ifndef __NativeScript__TNSFastEnumerationAdapter__
#define __NativeScript__TNSFastEnumerationAdapter__

namespace JSC {
    class JSGlobalObject;
}

namespace NativeScript {
NSUInteger TNSFastEnumerationAdapter(id self, NSFastEnumerationState* state, id buffer[], NSUInteger length, JSC::JSGlobalObject* globalObject);
}

#endif /* defined(__NativeScript__TNSFastEnumerationAdapter__) */
