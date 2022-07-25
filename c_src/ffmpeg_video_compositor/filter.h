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
 * @brief Create a filter graph from string description and stores it in the
 * given filter.
 *
 * @param filters_descr String description of the filter graph. This should
 * follow ffmpeg filter documentation.
 * @param filter  Pointer to the filter graph.
 * @return int Return code. Return 0 on success, negative value on failure.
 */
int init_filters(const char *filters_descr, FilterState *filter);

/**
 * @brief Create a filter description string in FFmpeg format and store it in
 * the given string. It assumes two input videos.
 *
 * @param filter_str Description destination (buffer)
 * @param filter_size Maximum size of the filter description (buffer size)
 * @param width Width of the videos
 * @param height Height of the videos
 * @param pixel_format Pixel format code of the videos
 * @return Number of characters written to the buffer
 */
int create_filter_description(char *filter_str, int filter_size, int width,
                              int height, int pixel_format);
