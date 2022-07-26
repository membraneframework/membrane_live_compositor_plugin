#include "filter.h"
/**
 * @brief Append a header of the filter description to the string (buffer).
 * Creates \p n_videos input nodes with output pads named [in_1], [in_2], ..,
 * [in_ \p n_videos].
 *
 * @param filters_str Description destination string (buffer)
 * @param filters_size Remaining size of the buffer
 * @param videos Array of input videos.
 * @param n_videos Size of the videos array
 * @return int
 */
static int append_input_nodes_filters_string(char *filters_str,
                                             int filters_size,
                                             RawVideo videos[], int n_videos);

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
 * (buffer). Assumes that the previous filter description provides one output
 * pad named [out]
 *
 * @param filters_str Description destination string (buffer)
 * @param filters_size Remaining size of the buffer
 * @return Number of characters written to the buffer
 */
static int finish_filters_string(char *filter_str, int filters_size);

static void cs_printAVError(const char *msg, int returnCode) {
    fprintf(stderr, "%s: %s\n", msg, av_err2str(returnCode));
}

int init_filter_description(char *filter_str, int filter_size,
                            RawVideo videos[], int n_videos) {
    int filter_end = 0;
    filter_end += append_input_nodes_filters_string(
        filter_str + filter_end, filter_size - filter_end, videos, n_videos);
    filter_end += apply_filters_options_string(filter_str + filter_end,
                                               filter_size - filter_end);
    filter_end += finish_filters_string(filter_str + filter_end,
                                        filter_size - filter_end);
    return filter_end;
}

static int append_input_nodes_filters_string(char *filters_str,
                                             int filters_size,
                                             RawVideo videos[], int n_videos) {
    int filter_end = 0;
    for (int i = 0; i < n_videos; ++i) {
        RawVideo *video = &videos[i];
        const char *video_description_format =
            "buffer="
            "video_size=%dx%d"
            ":pix_fmt=%d"
            ":time_base=%d/%d"
            "[in_%d];\n";
        const int time_base_num = 1;
        const int time_base_den = 1;
        const int input_pad_idx = i + 1;
        filter_end += snprintf(
            filters_str + filter_end, filters_size - filter_end,
            video_description_format, video->width, video->height,
            video->pixel_format, time_base_num, time_base_den, input_pad_idx);
    }
    return filter_end;
}

static int apply_filters_options_string(char *filters_str, int filters_size) {
    int filter_end = 0;
    // Temporary main filter description. It creates space for the second video
    // (pad) and then overlay them on top of each other (overlay)
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
