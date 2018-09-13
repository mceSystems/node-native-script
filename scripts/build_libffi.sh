exit 0

cd src/libffi

# TODO: This is based on libffi's travis script, but is the autogen.sh needed?
./autogen.sh
./generate-darwin-source-and-headers.py --only-ios
xcodebuild -project libffi.xcodeproj -target "libffi-iOS" -configuration Release -arch arm64 -sdk "iphoneos" build