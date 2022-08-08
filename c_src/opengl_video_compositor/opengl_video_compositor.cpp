#include "opengl_video_compositor.h"

#include <dlfcn.h>

#include <iostream>
#include <string_view>
#include <vector>

void check_egl_error(const std::string &str);

// FIXME: pretty much all egl calls may fail. Currently, this is not checked in
// any way.
UNIFEX_TERM init(UnifexEnv *env, raw_video first_video,
                 raw_video second_video) {
  std::string_view first_format(first_video.pixel_format);
  std::string_view second_format(second_video.pixel_format);
  if (first_video.width != second_video.width ||
      first_video.height != second_video.height ||
      first_format != second_format) {
    return init_result_error(env, "videos_of_different_formats");
  }

  if (first_format != "I420") {
    return init_result_error(env, "unsupported_pixel_format");
  }

  EGLDisplay egl_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  EGLint major, minor;
  eglInitialize(egl_display, &major, &minor);

  EGLint num_configs;
  EGLConfig config;
  // These specify what kind of contexts we'll be able to create
  EGLint config_attributes[] = {
      EGL_SURFACE_TYPE,    EGL_PBUFFER_BIT,    // ofscreen buffers only
      EGL_BLUE_SIZE,       8,                  // 8 blue bits per pixel    |
      EGL_GREEN_SIZE,      8,                  // 8 green bits per pixel   | support for RGB24 surfaces
      EGL_RED_SIZE,        8,                  // 8 red bits per pixel     |
      EGL_CONFORMANT,      EGL_OPENGL_ES3_BIT, // rendering done with OpenGL ES
      EGL_NONE,
  };

  eglChooseConfig(egl_display, config_attributes, nullptr, 0, &num_configs);

  eglChooseConfig(egl_display, config_attributes, &config, 1, &num_configs);
  check_egl_error("choose config");

  eglBindAPI(EGL_OPENGL_ES_API);
  check_egl_error("bind API");

  EGLint context_attributes[] = {
    EGL_CONTEXT_MAJOR_VERSION, 3,
    EGL_CONTEXT_MINOR_VERSION, 0,
    EGL_NONE,
  };

  EGLContext context =
      eglCreateContext(egl_display, config, EGL_NO_CONTEXT, context_attributes);
  check_egl_error("create context");
  eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, context);
  check_egl_error("make current");


  if (!gladLoadGLES2((GLADloadfunc) eglGetProcAddress)) {
    return init_result_error(env, "cannot_load_opengl");
  }

  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

  State *state = unifex_alloc_state(env);
  state->compositor = new Compositor(first_video.width, first_video.height);
  state->display = egl_display;
  state->context = context;

  eglMakeCurrent(state->display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                 EGL_NO_CONTEXT);
  return init_result_ok(env, state);
}

UNIFEX_TERM join_frames(UnifexEnv *env, UnifexPayload *upper,
                        UnifexPayload *lower, State *state) {
  // FIXME: Maybe figure out a better way to call this every time we do OpenGL
  // calls?
  //        So that you can't just forget to call this and segfault later on an
  //        OpenGL call Maybe this should even be locked somehow to prevent two
  //        threads from calling OpenGL functions simultaneously
  eglMakeCurrent(state->display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                 state->context);
  // FIXME: This is suboptimal, since we allocate a big vector every frame
  //        On the other hand, if we pass a raw pointer instead of a vector
  //        we can't ensure the target buffer has enough space allocated
  //        from within the `Compositor` instance.
  auto out = std::vector<char>();
  state->compositor->join_frames((char *)upper->data, (char *)lower->data, out);
  UnifexPayload payload;
  unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, out.size(), &payload);
  memcpy(payload.data, out.data(), out.size());

  eglMakeCurrent(state->display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                 EGL_NO_CONTEXT);
  return join_frames_result_ok(env, &payload);
}

void handle_destroy_state(UnifexEnv *env, State *state) {
  UNIFEX_UNUSED(env);
  delete state->compositor;
}

#define _EGL_ERROR_CASE(error) \
  case error: \
    std::cout << #error << std::endl; \
    break;

void check_egl_error(const std::string &str) {
  EGLint err;

  if((err = eglGetError()) != EGL_SUCCESS) {
    std::cout << str << " - EGL error: ";

    switch(err) {
      _EGL_ERROR_CASE(EGL_NOT_INITIALIZED)
      _EGL_ERROR_CASE(EGL_BAD_ACCESS)
      _EGL_ERROR_CASE(EGL_BAD_ALLOC)
      _EGL_ERROR_CASE(EGL_BAD_ATTRIBUTE)
      _EGL_ERROR_CASE(EGL_BAD_CONTEXT)
      _EGL_ERROR_CASE(EGL_BAD_CONFIG)
      _EGL_ERROR_CASE(EGL_BAD_CURRENT_SURFACE)
      _EGL_ERROR_CASE(EGL_BAD_DISPLAY)
      _EGL_ERROR_CASE(EGL_BAD_SURFACE)
      _EGL_ERROR_CASE(EGL_BAD_MATCH)
      _EGL_ERROR_CASE(EGL_BAD_PARAMETER)
      _EGL_ERROR_CASE(EGL_BAD_NATIVE_PIXMAP)
      _EGL_ERROR_CASE(EGL_BAD_NATIVE_WINDOW)
      _EGL_ERROR_CASE(EGL_CONTEXT_LOST)
    }
  }
}
