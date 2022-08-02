#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libavutil/parseutils.h>
#include <stdio.h>

#include "raw_video.h"

#define SIZE(x) ((int)(sizeof(x) / sizeof(x[0])))

typedef struct FilterState {
  AVFilterContext **inputs;
  unsigned n_inputs;
  AVFilterContext *output;
  AVFilterGraph *graph;
} FilterState;

typedef struct VState {
  FilterState filter;
  RawVideo videos[2];
} VState;

typedef struct Vec2 {
  int x, y;
} Vec2;

int init_filters_graph(const char *filters_descr, FilterState *filter,
                       int n_inputs);

int get_filter_description(char *filter_str, int filter_size, RawVideo videos[],
                           Vec2 positions[], int n_videos);

void free_filter_state(FilterState *filter);

void print_av_error(const char *msg, int error_code);
