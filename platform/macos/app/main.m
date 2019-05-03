#import <Cocoa/Cocoa.h>

#include <mbgl/mbgl.hpp>

int main(int argc, const char * argv[]) {
    mbgl::Init();

    int ret = NSApplicationMain(argc, argv);

    mbgl::Cleanup();

    return ret;
}
