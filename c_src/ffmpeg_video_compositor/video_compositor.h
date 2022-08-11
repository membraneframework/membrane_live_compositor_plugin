#pragma once

#include "vstate.h"

typedef struct VideoCompositorState {
  VState vstate;
  int last_pts;
} State;
#include "_generated/video_compositor.h"
