#include "jni.hpp"
#include <jni/jni.hpp>

#include <mbgl/mbgl.hpp>

extern "C" JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *) {
    assert(vm != nullptr);

    // Deliberately not calling mbgl::Cleanup
    // because JNI_OnUnload is useless.
    mbgl::Init();

    mbgl::android::registerNatives(vm);
    return JNI_VERSION_1_6;
}

