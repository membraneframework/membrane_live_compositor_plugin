#include <dlfcn.h>
#include <iostream>
#include <vector>

#include "opengl_video_compositor.h"

UNIFEX_TERM init(UnifexEnv *env, int width, int height) {
    State *state = unifex_alloc_state(env);

    dlopen("libEGL.dylib", RTLD_LAZY);
    
    EGLDisplay egl_display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    EGLint major, minor;
    eglInitialize(egl_display, &major, &minor);

    EGLint num_configs;
    EGLConfig config;
    // TODO: figure out what these fields mean and whether those are correct values
    EGLint config_attributes[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_BLUE_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_RED_SIZE, 8,
        EGL_DEPTH_SIZE, 8,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
        EGL_NONE,        
    };

    eglChooseConfig(egl_display, config_attributes, &config, 1, &num_configs);

    eglBindAPI(EGL_OPENGL_API);

    EGLContext context = eglCreateContext(egl_display, config, EGL_NO_CONTEXT, NULL);
    eglMakeCurrent(egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, context);

    if(!gladLoadGL()) {
        return init_result_error(env, "cannot_load_glad");
    }
    glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
    state->compositor = new Compositor(width, height);
    state->display = egl_display;
    state->context = context;

    return init_result_ok(env, state);
}

UNIFEX_TERM join_frames(UnifexEnv *env,  UnifexPayload *upper, UnifexPayload *lower, State *state) {
    // FIXME: maybe figure out a better (possibly RAII) way to call this every time we do opengl calls?
    //        So that you can't just forget to call this and segfault
    eglMakeCurrent(state->display, EGL_NO_SURFACE, EGL_NO_SURFACE, state->context);
    // FIXME: this is suboptimal, since we allocate a big vector every frame
    auto out = std::vector<char>();
    state->compositor->join_frames((char*)upper->data, (char*)lower->data, out);
    UnifexPayload payload;
    unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, out.size(), &payload);
    memcpy(payload.data, out.data(), out.size());

    return join_frames_result_ok(env, &payload);
}

void handle_destroy_state(UnifexEnv *env, State *state) {
    UNIFEX_UNUSED(env);
    delete state->compositor;
}