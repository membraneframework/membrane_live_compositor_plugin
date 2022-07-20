#include <libavfilter/buffersink.h>
#include <libavfilter/buffersrc.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libavutil/parseutils.h>
#include <stdio.h>
#include <unifex/payload.h>
#include <unifex/unifex.h>

typedef struct VFilterState {
    AVFilterContext *buffersink_ctx;
    AVFilterContext *buffersrc_ctx;
    AVFilterGraph *filter_graph;
    int width;
    int height;
    int pixel_format;
    char *text;
} State;

int init_filters(const char *filters_descr, State *state);
int get_pixel_format(const char *fmt_name);
void handle_destroy_state(UnifexEnv *env, State *state);

// #include "_generated/filter.h"