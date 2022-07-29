#pragma once

// #define GLFW_INCLUDE_NONE
// #include <GLFW/glfw3.h>
#include <EGL/egl.h>

#include "Compositor.h"

struct State {
    // Compositor compositor;
    Compositor *compositor;
    // GLFWwindow *window;
    EGLDisplay display;
    EGLSurface surface;
    EGLContext context;
};
#include "_generated/opengl_video_compositor.h"