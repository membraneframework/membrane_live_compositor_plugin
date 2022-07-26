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

/**
 * @brief Creates a filter graph from the string description and stores it in
 * the given filter.
 *
 * @param filters_descr String description of the filter graph. This should
 * follow FFmpeg filter documentation.
 * @param filter  Pointer to the filter graph.
 * @return Return code. Return 0 on success, a negative value on failure.
 */
int init_filters(const char *filters_descr, FilterState *filter);

/**
 * @brief Creates a filter description string in an FFmpeg format and stores it
 * in the given string.
 *
 * @param filter_str Description destination (buffer)
 * @param filter_size Maximum size of the filter description (buffer size)
 * @param videos Array of input videos.
 * @param n_videos Size of the videos array
 * @return int
 */
int init_filter_description(char *filter_str, int filter_size,
                            RawVideo videos[], int n_videos);
