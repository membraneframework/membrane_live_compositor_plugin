#pragma once

#include <EGL/egl.h>

#include "Compositor.h"

struct State {
  Compositor *compositor;
  EGLDisplay display;
  EGLSurface surface;
  EGLContext context;
};
#include "_generated/opengl_video_compositor.h"