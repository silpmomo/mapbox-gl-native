#include <mbgl/mbgl.hpp>

#include <mbgl/actor/scheduler.hpp>
#include <mbgl/test.hpp>
#include <mbgl/test/util.hpp>

#include <gtest/gtest.h>

namespace mbgl {

int runTests(int argc, char *argv[]) {
    mbgl::Init();

#if TEST_HAS_SERVER
    auto server = std::make_unique<test::Server>("test/storage/server.js");
#endif

    testing::InitGoogleTest(&argc, argv);
    auto ret = RUN_ALL_TESTS();

    mbgl::Cleanup();

    return ret;
}

} // namespace mbgl
