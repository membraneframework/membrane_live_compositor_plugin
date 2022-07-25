#include "video_compositor.h"

static UNIFEX_TERM create_unifex_filter(UnifexEnv *env,
                                        const char *filter_description,
                                        int pixel_format, int width,
                                        int height);

/**
 * @brief Initialize the state of the video compositor, create filter graph
 *
 * @param env Unifex environment
 * @param width Width of the videos
 * @param height Height of the videos
 * @param pixel_format_name Pixel format of the videos, given in a string
 * @return UNIFEX_TERM
 */
UNIFEX_TERM create(UnifexEnv *env, int width, int height,
                   char *pixel_format_name) {
    UNIFEX_TERM result;
    char filter_str[512];
    int pixel_format = get_pixel_format(pixel_format_name);
    if (pixel_format < 0) {
        result = create_result_error(env, "unsupported_pixel_format");
        goto end;
    }
    create_filter_description(filter_str, sizeof filter_str, width, height,
                              pixel_format);
    result = create_unifex_filter(env, filter_str, pixel_format, width, height);
end:
    return result;
}

/**
 * @brief Create a unifex filter object
 *
 * @param env Unifex environment
 * @param filter_description Description of the FFmpeg filter (transformation
 * graph), given in a string
 * @param pixel_format Pixel format code of the videos
 * @param width Width of the videos
 * @param height Height of the videos
 * @return UNIFEX_TERM
 */
static UNIFEX_TERM create_unifex_filter(UnifexEnv *env,
                                        const char *filter_description,
                                        int pixel_format, int width,
                                        int height) {
    UNIFEX_TERM result;

    State *state = unifex_alloc_state(env);
    for (int i = 0; i < SIZE(state->vstate.videos); i++) {
        state->vstate.videos[i].height = height;
        state->vstate.videos[i].width = width;
        state->vstate.videos[i].pixel_format = pixel_format;
    }

    if (init_filters(filter_description, &state->vstate.filter) < 0) {
        result = create_result_error(env, "error_creating_filters");
        goto exit_create;
    }
    result = create_result_ok(env, state);

exit_create:
    unifex_release_state(env, state);
    return result;
}

/**
 * @brief Apply a filter on the given frames (compose them) and stores the
 * result in the environment.
 *
 * @param env Unifex environment
 * @param left_payload First frame
 * @param right_payload Second frame
 * @param state State with the initialised filter
 * @return UNIFEX_TERM
 */
UNIFEX_TERM apply_filter(UnifexEnv *env, UnifexPayload *left_payload,
                         UnifexPayload *right_payload, State *state) {
    UNIFEX_TERM res;
    int ret = 0;
    UnifexPayload *payloads[] = {left_payload, right_payload};
    AVFrame *frames[] = {av_frame_alloc(), av_frame_alloc()};
    AVFrame *filtered_frame = av_frame_alloc();

    if (!frames[0] || !frames[1] || !filtered_frame) {
        res = apply_filter_result_error(env, "error_allocating_frame");
        goto exit_filter;
    }

    for (int i = 0; i < SIZE(frames); i++) {
        AVFrame *frame = frames[i];
        RawVideo *video = &state->vstate.videos[i];
        UnifexPayload *payload = payloads[i];
        frame->format = video->pixel_format;
        frame->width = video->width;
        frame->height = video->height;
        av_image_fill_arrays(frame->data, frame->linesize, payload->data,
                             frame->format, frame->width, frame->height, 1);
    }

    /* feed the filtergraph */
    FilterState *filter = &state->vstate.filter;
    for (int i = 0; i < SIZE(filter->inputs); ++i) {
        AVFilterContext *input = filter->inputs[i];
        AVFrame *frame = frames[i];
        if (av_buffersrc_add_frame_flags(input, frame,
                                         AV_BUFFERSRC_FLAG_KEEP_REF) < 0) {
            res = apply_filter_result_error(env, "error_feeding_filtergraph");
            goto exit_filter;
        }
    }

    /* pull filtered frame from the filtergraph - in drawtext filter there
     * should always be 1 frame on output for each frame on input*/
    ret = av_buffersink_get_frame(filter->output, filtered_frame);
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
    if (frames[0] != NULL) av_frame_free(&frames[0]);
    if (frames[1] != NULL) av_frame_free(&frames[1]);
    if (filtered_frame != NULL) av_frame_free(&filtered_frame);
    return res;
}

/**
 * @brief Clean up the state
 *
 * @param env Unifex environment
 * @param state State
 */
void handle_destroy_state(UnifexEnv *env, State *state) {
    UNIFEX_UNUSED(env);
    FilterState *filter = &state->vstate.filter;
    if (filter->graph != NULL) {
        avfilter_graph_free(&filter->graph);
    }
    filter->inputs[0] = NULL;
    filter->inputs[1] = NULL;
    filter->output = NULL;
}