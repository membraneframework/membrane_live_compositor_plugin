#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libavutil/parseutils.h>
#include <stdio.h>

#include "raw_video.h"

#define SIZE(x) ((int)(sizeof(x) / sizeof(x[0])))

typedef struct FilterState {
  AVFilterContext *inputs[2];
  AVFilterContext *output;
  AVFilterGraph *graph;
} FilterState;

typedef struct VState {
  FilterState filter;
  RawVideo videos[2];
} VState;

int init_filters(const char *filters_descr, FilterState *filter);

int init_filter_description(char *filter_str, int filter_size,
                            RawVideo videos[], int n_videos);
