#include "opengl_video_compositor.h"
#include <vector>

UNIFEX_TERM init(UnifexEnv *env, int width, int height) {
    State *state = unifex_alloc_state(env);

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

void handle_destroy_state(UnifexEnv *env) {
    UNIFEX_UNUSED(env);
}