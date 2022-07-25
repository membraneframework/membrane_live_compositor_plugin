#include "filter.h"
/**
 * @brief Append a header of the filter description to the string (buffer).
 * Creates two input pads with output pads named [in_1] and [in_2]
 *
 * @param filters_str Description destination string (buffer)
 * @param filters_size Remaining size of the buffer
 * @param width Width of the videos
 * @param height Height of the videos
 * @param pixel_format Pixel format code of the videos
 * @return Number of characters written to the buffer
 */
static int init_filters_string(char *filters_str, int filters_size, int width,
                               int height, int pixel_format);

/**
 * @brief Append a main filter description (transformation graph) to the string
 * (buffer)
 *
 * @param filters_str Description destination string (buffer)
 * @param filters_size Remaining size of the buffer
 * @return Number of characters written to the buffer
 */
static int apply_filters_options_string(char *filters_str, int filters_size);

/**
 * @brief Append a footer filter description to the string
 * (buffer). Assumes that previous filter description provides one output pad
 * named [out]
 *
 * @param filters_str Description destination string (buffer)
 * @param filters_size Remaining size of the buffer
 * @return Number of characters written to the buffer
 */
static int finish_filters_string(char *filter_str, int filters_size);

static void cs_printAVError(const char *msg, int returnCode) {
    fprintf(stderr, "%s: %s\n", msg, av_err2str(returnCode));
}

int create_filter_description(char *filter_str, int filters_size, int width,
                              int height, int pixel_format) {
    int filter_end = 0;
    filter_end +=
        init_filters_string(filter_str + filter_end, filters_size - filter_end,
                            width, height, pixel_format);
    filter_end += apply_filters_options_string(filter_str + filter_end,
                                               filters_size - filter_end);
    filter_end += finish_filters_string(filter_str + filter_end,
                                        filters_size - filter_end);
    return filter_end;
}

static int init_filters_string(char *filters_str, int filters_size, int width,
                               int height, int pixel_format) {
    const int n_videos = 2;
    int filter_end = 0;
    for (int i = 0; i < n_videos; ++i) {
        filter_end +=
            snprintf(filters_str + filter_end, filters_size - filter_end,
                     "buffer=video_size=%dx%d:pix_fmt=%d:time_base=%d/"
                     "%d [in_%d];\n",
                     width, height, pixel_format, 1, 1, i + 1);
    }
    return filter_end;
}

static int apply_filters_options_string(char *filters_str, int filters_size) {
    int filter_end = 0;
    const char *filter_descr =
        "[in_1]pad=iw:ih*2[src]; "
        "[src][in_2]overlay=0:h[out];\n";
    filter_end += snprintf(filters_str + filter_end, filters_size - filter_end,
                           "%s", filter_descr);
    return filter_end;
}

static int finish_filters_string(char *filters_str, int filters_size) {
    int filter_end = 0;

    filter_end += snprintf(filters_str + filter_end, filters_size - filter_end,
                           "%s", "[out] buffersink");
    return filter_end;
}

int init_filters(const char *filters_str, FilterState *filter) {
    filter->graph = avfilter_graph_alloc();
    AVFilterGraph *graph = filter->graph;

    if (graph == NULL) {
        fprintf(stderr, "Cannot allocate filter graph.");
        return -1;
    }

    AVFilterInOut *gis = NULL;
    AVFilterInOut *gos = NULL;

    int ret = avfilter_graph_parse2(graph, filters_str, &gis, &gos);
    if (ret < 0) {
        cs_printAVError("Cannot parse graph.", ret);
        goto end;
    }

    ret = avfilter_graph_config(graph, NULL);
    if (ret < 0) {
        cs_printAVError("Cannot configure graph.", ret);
        goto end;
    }

    filter->inputs[0] = graph->filters[0];
    filter->inputs[1] = graph->filters[1];
    filter->output = graph->filters[graph->nb_filters - 1 - 1];

end:
    avfilter_inout_free(&gis);
    avfilter_inout_free(&gos);
    return ret;
}