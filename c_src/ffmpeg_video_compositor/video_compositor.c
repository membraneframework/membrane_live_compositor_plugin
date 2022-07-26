#include "video_compositor.h"

/**
 * @brief Create a unifex filter object
 *
 * @param env Unifex environment
 * @param filter_description Description of the FFmpeg filter (transformation
 * graph), given in a string
 * @param videos Array of input videos
 * @param n_videos Size of the videos array
 * @return UNIFEX_TERM
 */
static UNIFEX_TERM init_unifex_filter(UnifexEnv *env,
                                      const char *filter_description,
                                      RawVideo videos[], int n_videos);

/**
 * @brief Initializes the state of the video compositor and creates a filter
 * graph. The function assumes two input videos and one output video.
 *
 * @param env Unifex environment
 * @param first_video First input video
 * @param second_video Second input video
 * @return UNIFEX_TERM
 */
UNIFEX_TERM init(UnifexEnv *env, raw_video first_video,
                 raw_video second_video) {
  UNIFEX_TERM result;
  char filter_str[512];

  RawVideo videos[2];
  if (init_raw_video(&videos[0], first_video.width, first_video.height,
                     first_video.pixel_format) < 0) {
    result = init_result_error(env, "unsupported_pixel_format");
    goto end;
  }
  if (init_raw_video(&videos[1], second_video.width, second_video.height,
                     second_video.pixel_format) < 0) {
    result = init_result_error(env, "unsupported_pixel_format");
    goto end;
  }

  get_filter_description(filter_str, sizeof filter_str, videos, SIZE(videos));
  result = init_unifex_filter(env, filter_str, videos, SIZE(videos));
end:
  return result;
}

static UNIFEX_TERM init_unifex_filter(UnifexEnv *env,
                                      const char *filter_description,
                                      RawVideo videos[], int n_videos) {
  UNIFEX_TERM result;
  State *state = unifex_alloc_state(env);

  if (SIZE(state->vstate.videos) != n_videos) {
    result = init_result_error(env, "error_expected_two_input_videos");
    goto exit_create;
  }
  for (int i = 0; i < SIZE(state->vstate.videos); i++) {
    state->vstate.videos[i] = videos[i];
  }

  if (init_filters_graph(filter_description, &state->vstate.filter) < 0) {
    result = init_result_error(env, "error_creating_filters");
    goto exit_create;
  }
  result = init_result_ok(env, state);

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
 * @param state State with the initialized filter
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

  /* feed the filter graph */
  FilterState *filter = &state->vstate.filter;
  for (int i = 0; i < SIZE(filter->inputs); ++i) {
    AVFilterContext *input = filter->inputs[i];
    AVFrame *frame = frames[i];
    if (av_buffersrc_add_frame_flags(input, frame, AV_BUFFERSRC_FLAG_KEEP_REF) <
        0) {
      res = apply_filter_result_error(env, "error_feeding_filtergraph");
      goto exit_filter;
    }
  }

  /* pull the filtered frame from the filter graph
   * should always be 1 frame on output for each frame on input*/
  ret = av_buffersink_get_frame(filter->output, filtered_frame);
  if (ret < 0) {
    res = apply_filter_result_error(env, "error_pulling_from_filtergraph");
    goto exit_filter;
  }

  UnifexPayload payload_frame;
  size_t payload_size = av_image_get_buffer_size(
      filtered_frame->format, filtered_frame->width, filtered_frame->height, 1);
  unifex_payload_alloc(env, UNIFEX_PAYLOAD_BINARY, payload_size,
                       &payload_frame);

  if (av_image_copy_to_buffer(payload_frame.data, payload_size,
                              (const uint8_t *const *)filtered_frame->data,
                              filtered_frame->linesize, filtered_frame->format,
                              filtered_frame->width, filtered_frame->height,
                              1) < 0) {
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
