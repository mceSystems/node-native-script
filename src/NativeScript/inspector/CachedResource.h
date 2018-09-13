#ifndef NativeScript_CachedResource_h
#define NativeScript_CachedResource_h

#include "JavaScriptCore/inspector/InspectorProtocolObjects.h"
#include <JavaScriptCore/inspector/InspectorBackendDispatchers.h>

namespace Inspector {
class CachedResource {
public:
    CachedResource();
    CachedResource(WTF::String displayName, WTF::String filePath);

    WTF::String mimeType() {
        return m_mimeType;
    }
    WTF::String displayName() {
        return m_displayName;
    }
    WTF::String content(ErrorString& out_error);
    bool hasTextContent();
    Inspector::Protocol::Page::ResourceType type() {
        return m_type;
    }

private:
    WTF::String m_filePath;
    WTF::String m_bundlePath;
    WTF::String m_displayName;
    WTF::String m_mimeType;
    WTF::String m_content;
    Inspector::Protocol::Page::ResourceType m_type;

    static WTF::HashMap<WTF::String, Inspector::Protocol::Page::ResourceType> m_mimeTypeMap;

    static Inspector::Protocol::Page::ResourceType resourceTypeByMimeType(WTF::String mimeType);
};

WTF::HashMap<WTF::String, Inspector::CachedResource>& cachedResources(NativeScript::GlobalObject&);
} // namespace Inspector

#endif
