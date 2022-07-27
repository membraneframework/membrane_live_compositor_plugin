#pragma once

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

#include "Compositor.h"

struct State {
    Compositor compositor;
    GLFWwindow *window;
};
#include "_generated/opengl_video_compositor.h"