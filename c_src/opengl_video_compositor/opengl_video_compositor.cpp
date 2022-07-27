#include <iostream>
#include <vector>

#include "opengl_video_compositor.h"

void errorcb(int error, const char *desc) {
    std::cout << "GLFW error " << error << ": " << desc << std::endl;
}

UNIFEX_TERM init(UnifexEnv *env, int width, int height) {
    State *state = unifex_alloc_state(env);

    glfwInit();
    glfwSetErrorCallback(errorcb);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    std::cout << "glfw init+hints" << std::endl;

    GLFWwindow *window = glfwCreateWindow(1, 1, "", nullptr, nullptr);
    std::cout << "glfw create window" << std::endl;
    if(window == nullptr) {
        glfwTerminate();
        return init_result_error(env, "cannot_create_window");
    }

    glfwMakeContextCurrent(window);

    if(!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        return init_result_error(env, "cannot_load_glad");
    }
    glfwHideWindow(window);
    glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
    state->window = window;
    std::cout << "window" << std::endl;
    state->compositor = Compositor(width, height);

    return init_result_ok(env, state);
}

UNIFEX_TERM join_frames(UnifexEnv *env,  UnifexPayload *upper, UnifexPayload *lower, State *state) {
    auto out = std::vector<char>();
    state->compositor.join_frames((char*)upper->data, (char*)lower->data, out);
    UnifexPayload payload;
    unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, out.size(), &payload);
    memcpy(payload.data, out.data(), out.size());

    return join_frames_result_ok(env, &payload);
}

void handle_destroy_state(UnifexEnv *env, State *state) {
    UNIFEX_UNUSED(env);
    UNIFEX_UNUSED(state);
}