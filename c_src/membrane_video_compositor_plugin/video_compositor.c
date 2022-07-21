#include "video_compositor.h"

static void create_filter_description(char *filter_descr, int len);

static UNIFEX_TERM create_unifex_filter(UnifexEnv *env,
                                        const char *filter_description,
                                        const char *pixel_format_name,
                                        int width, int height);

UNIFEX_TERM create(UnifexEnv *env, int width, int height,
                   char *pixel_format_name) {
    UNIFEX_TERM result;
    char filter_descr[512];
    create_filter_description(filter_descr, sizeof filter_descr);

    result = create_unifex_filter(env, filter_descr, pixel_format_name, width,
                                  height);
    return result;
}

static void create_filter_description(char *filter_descr, int len) {
    // filter_descr += snprintf(filter_descr, len, "drawtext=text=%s", text);
    filter_descr +=
        snprintf(filter_descr, len, "overlay=10:main_h-overlay_h-10");
}

void handle_destroy_state(UnifexEnv *env, State *state) {
    UNIFEX_UNUSED(env);
    if (state->vstate.filter_graph != NULL) {
        avfilter_graph_free(&state->vstate.filter_graph);
    }
    state->vstate.buffersink_ctx = NULL;
    state->vstate.buffersrc_ctx = NULL;
}

UNIFEX_TERM apply_filter(UnifexEnv *env, UnifexPayload *payload, State *state) {
    UNIFEX_TERM res;
    int ret = 0;
    AVFrame *frame = av_frame_alloc();
    AVFrame *filtered_frame = av_frame_alloc();

    if (!frame || !filtered_frame) {
        res = apply_filter_result_error(env, "error_allocating_frame");
        goto exit_filter;
    }

    frame->format = state->vstate.pixel_format;
    frame->width = state->vstate.width;
    frame->height = state->vstate.height;
    av_image_fill_arrays(frame->data, frame->linesize, payload->data,
                         frame->format, frame->width, frame->height, 1);

    /* feed the filtergraph */
    if (av_buffersrc_add_frame_flags(state->vstate.buffersrc_ctx, frame,
                                     AV_BUFFERSRC_FLAG_KEEP_REF) < 0) {
        res = apply_filter_result_error(env, "error_feeding_filtergraph");
        goto exit_filter;
    }

    /* pull filtered frame from the filtergraph - in drawtext filter there
     * should always be 1 frame on output for each frame on input*/
    ret = av_buffersink_get_frame(state->vstate.buffersink_ctx, filtered_frame);
    if (ret < 0) {
        res = apply_filter_result_error(env, "error_pulling_from_filtergraph");
        goto exit_filter;
    }

    UnifexPayload payload_frame;
    size_t payload_size =
        av_image_get_buffer_size(filtered_frame->format, filtered_frame->width,
                                 filtered_frame->height, 1);
    unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, payload_size,
                         &payload_frame);

    if (av_image_copy_to_buffer(payload_frame.data, payload_size,
                                (const uint8_t *const *)filtered_frame->data,
                                filtered_frame->linesize,
                                filtered_frame->format, filtered_frame->width,
                                filtered_frame->height, 1) < 0) {
        res = apply_filter_result_error(env, "copy_to_payload");
        goto exit_filter;
    }
    res = apply_filter_result_ok(env, &payload_frame);
exit_filter:
    if (frame != NULL) av_frame_free(&frame);
    if (filtered_frame != NULL) av_frame_free(&filtered_frame);
    return res;
}

static UNIFEX_TERM create_unifex_filter(UnifexEnv *env,
                                        const char *filter_description,
                                        const char *pixel_format_name,
                                        int width, int height) {
    UNIFEX_TERM result;
    State *state = unifex_alloc_state(env);
    state->vstate.width = width;
    state->vstate.height = height;

    int pix_fmt = get_pixel_format(pixel_format_name);
    if (pix_fmt < 0) {
        result = create_result_error(env, "unsupported_pixel_format");
        goto exit_create;
    }
    state->vstate.pixel_format = pix_fmt;

    if (init_filters(filter_description, &state->vstate) < 0) {
        result = create_result_error(env, "error_creating_filters");
        goto exit_create;
    }
    result = create_result_ok(env, state);

exit_create:
    unifex_release_state(env, state);
    return result;
}
