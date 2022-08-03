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
                                      RawVideo videos[], unsigned n_videos);

/**
 * @brief Initializes the state of the video compositor and creates a filter
 * graph. The function assumes two input videos and one output video.
 *
 * @param env Unifex environment
 * @param first_video First input video
 * @param second_video Second input video
 * @return UNIFEX_TERM
 */
UNIFEX_TERM init(UnifexEnv *env, raw_video input_videos[],
                 unsigned n_input_videos) {
  // raw_video input_videos[] = {first_video, second_video};
  // const unsigned n_input_videos = SIZE(input_videos);
  UNIFEX_TERM result;
  char filter_str[4096];

  RawVideo videos[N_MAX_VIDEOS];
  const unsigned n_videos = n_input_videos;

  for (unsigned i = 0; i < n_videos; i++) {
    raw_video input_video = input_videos[i % n_input_videos];
    if (init_raw_video(&videos[i], input_video.width, input_video.height,
                       input_video.pixel_format) < 0) {
      result = init_result_error(env, "unsupported_pixel_format");
      goto end;
    }
  }

  Vec2 positions[N_MAX_VIDEOS];

  positions[0] = (Vec2){.x = 0, .y = 0};

  RawVideo first_video = videos[0];
  for (int i = 1; i < SIZE(positions); i++) {
    positions[i] = (Vec2){.x = 0, .y = first_video.height / i};
  }

  get_filter_description(filter_str, sizeof filter_str, videos, positions,
                         n_videos);
  // printf("%s\n", filter_str);
  result = init_unifex_filter(env, filter_str, videos, n_videos);

end:
  return result;
}

static UNIFEX_TERM init_unifex_filter(UnifexEnv *env,
                                      const char *filter_description,
                                      RawVideo videos[], unsigned n_videos) {
  UNIFEX_TERM result;
  State *state = unifex_alloc_state(env);
  alloc_vstate(&state->vstate, n_videos);

  if (state->vstate.n_videos < n_videos) {
    result = init_result_error(env, "error_expected_less_input_videos");
    goto exit_create;
  }
  for (unsigned i = 0; i < state->vstate.n_videos; i++) {
    state->vstate.videos[i] = videos[i];
  }

  if (init_filters_graph(filter_description, &state->vstate.filter, n_videos) <
      0) {
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
UNIFEX_TERM apply_filter(UnifexEnv *env, UnifexPayload *payloads[],
                         unsigned n_payloads, State *main_state) {
  UNIFEX_TERM res;
  int ret = 0;
  AVFrame *filtered_frame = av_frame_alloc();

  VState *state = &main_state->vstate;

  if (state->n_videos != n_payloads) {
    res = apply_filter_result_error(env, "error_wrong_number_of_frames");
    goto exit_filter;
  }

  if (!filtered_frame) {
    res = apply_filter_result_error(env, "error_allocating_frame");
    goto exit_filter;
  }

  for (unsigned i = 0; i < state->n_videos; i++) {
    AVFrame *frame = state->input_frames[i];
    RawVideo *video = &state->videos[i];
    UnifexPayload *payload = payloads[i];
    frame->format = video->pixel_format;
    frame->width = video->width;
    frame->height = video->height;
    av_image_fill_arrays(frame->data, frame->linesize, payload->data,
                         frame->format, frame->width, frame->height, 1);
  }

  /* feed the filter graph */
  FilterState *filter = &state->filter;
  for (unsigned i = 0; i < filter->n_inputs; ++i) {
    AVFilterContext *input = filter->inputs[i];
    AVFrame *frame = state->input_frames[i];
    if (av_buffersrc_add_frame_flags(input, frame, AV_BUFFERSRC_FLAG_KEEP_REF) <
        0) {
      res = apply_filter_result_error(env, "error_feeding_filtergraph");
      goto exit_filter;
    }
  }

  // printf("%s %d %d\n", filter->inputs[0]->name, filter->inputs[0]->nb_inputs,
  //        filter->inputs[0]->nb_outputs);
  // printf("%s %d %d\n", filter->inputs[1]->name, filter->inputs[1]->nb_inputs,
  //        filter->inputs[1]->nb_outputs);
  // printf("%s %d %d\n", filter->output->name, filter->output->nb_inputs,
  //        filter->output->nb_outputs);

  /* pull the filtered frame from the filter graph
   * should always be 1 frame on output for each frame on input*/
  ret = av_buffersink_get_frame(filter->output, filtered_frame);
  if (ret < 0) {
    print_av_error("Error pulling from filtergraph", ret);
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
  free_vstate(&state->vstate);
}
