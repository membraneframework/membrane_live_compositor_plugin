#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libavutil/parseutils.h>
#include <stdio.h>

typedef struct FilterState {
    AVFilterContext *inputs[2];
    AVFilterContext *output;
    AVFilterGraph *graph;
} FilterState;

typedef struct VideoState {
    int width;
    int height;
    int pixel_format;
} VideoState;

typedef struct {
    FilterState filter;
    VideoState videos[2];
} VState;

int init_filters(const char *filters_descr, VState *state);
int get_pixel_format(const char *fmt_name);

// #include "_generated/filter.h"