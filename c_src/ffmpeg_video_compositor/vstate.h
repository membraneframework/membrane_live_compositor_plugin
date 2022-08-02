#pragma once

#include "filter.h"

typedef struct VState {
  FilterState filter;
  RawVideo *videos;
  AVFrame **input_frames;
  unsigned n_videos;
} VState;

void alloc_vstate(VState *state, unsigned n_videos);

void free_vstate(VState *state);
