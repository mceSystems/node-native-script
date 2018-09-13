#!/bin/bash

NODE_GYP="$1/deps/npm/node_modules/node-gyp/bin/node-gyp.js"

$NODE_GYP clean --verbose
$NODE_GYP configure --verbose --nodedir=/Users/kobyboyango/Desktop/node-ios/mce/src/poc/node-ios/node/ --arch=arm64 --OS=ios --node_engine=jsc
$NODE_GYP build --verbose --nodedir=/Users/kobyboyango/Desktop/node-ios/mce/src/poc/node-ios/node/ --arch=arm64 --OS=ios --node_engine=jsc

codesign --sign "$2" --force ./build/Release/NativeScript.node

npm install