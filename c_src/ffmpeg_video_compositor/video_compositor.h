#pragma once

#include "vstate.h"

typedef struct VideoCompositorState {
  VState vstate;
  int n_frames;
} State;
#include "_generated/video_compositor.h"
