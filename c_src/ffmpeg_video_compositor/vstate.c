#include "vstate.h"

void alloc_vstate(VState *state, unsigned n_videos) {
  state->videos = malloc(n_videos * sizeof(*state->videos));
  state->input_frames = malloc(n_videos * sizeof(*state->input_frames));
  state->n_videos = n_videos;
  for (unsigned i = 0; i < n_videos; i++) {
    state->input_frames[i] = av_frame_alloc();
  }
}

void free_vstate(VState *state) {
  for (unsigned i = 0; i < state->n_videos; i++) {
    av_frame_free(&state->input_frames[i]);
  }
  free(state->videos);
  free(state->input_frames);
  free_filter_state(&state->filter);
  state->videos = NULL;
  state->input_frames = NULL;
  state->n_videos = 0;
}
