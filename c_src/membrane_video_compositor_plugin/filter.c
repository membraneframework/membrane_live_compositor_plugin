#include "filter.h"

static void cs_printAVError(const char *msg, int returnCode) {
    fprintf(stderr, "%s: %s\n", msg, av_err2str(returnCode));
}

int get_pixel_format(const char *fmt_name) {
    int pix_fmt = -1;
    if (strcmp(fmt_name, "I420") == 0) {
        pix_fmt = AV_PIX_FMT_YUV420P;
    } else if (strcmp(fmt_name, "I422") == 0) {
        pix_fmt = AV_PIX_FMT_YUV422P;
    } else if (strcmp(fmt_name, "I444") == 0) {
        pix_fmt = AV_PIX_FMT_YUV444P;
    }
    return pix_fmt;
}

void create_filter_description(char *filter_str, int filter_size, int width,
                               int height, int pixel_format) {
    int filter_end = 0;
    filter_end +=
        init_filters_string(filter_str + filter_end, filter_size - filter_end,
                            width, height, pixel_format);
    filter_end += apply_filters_options_string(filter_str + filter_end,
                                               filter_size - filter_end);
    filter_end += finish_filters_string(filter_str + filter_end,
                                        filter_size - filter_end);
}

static int init_filters_string(char *filters_str, int filter_size, int width,
                               int height, int pixel_format) {
    // char filters_str[1024];
    int filter_end = 0;
    for (int i = 0; i < n_videos; ++i) {
        snprintf(filters_str + filter_end, filter_size - filter_end,
                 "buffer=video_size=%dx%d:pix_fmt=%d:time_base=%d/"
                 "%d [in_%d];\n",
                 width, height, pixel_format, 1, 1, i + 1);
    }
    return filter_end;
}

static int apply_filters_options_string(char *filters_str, int filter_size) {
    int filter_end = 0;
    // const char *filter_descr =
    //     "[in_1]scale=78:24[a]; "
    //     "[in_2]scale=38:12[b]; "
    //     "[a]pad=iw*2:ih[src]; "
    //     "[b]deshake[filt]; "
    //     "[src][filt]overlay=w*(1-t*0.3)[out];\n";
    const char *filter_descr =
        "[in_1]pad=iw*2:ih[src]; "
        "[src][in_2]overlay=w[out];\n";
    filter_end += snprintf(filters_str + filter_end, filter_size - filter_end,
                           "%s", filter_descr);
    return filter_end;
}

static int finish_filters_string(char *filter_str, int filter_size) {
    int filter_end = 0;

    filter_end += snprintf(filters_str + filter_end, filter_size - filter_end,
                           "%s", "[out] buffersink");
    return filter_end;
}

int init_filters(const char *filters_descr, VState *state) {
    state->filter->graph = avfilter_graph_alloc();
    AVFilterGraph *graph = state->filter->graph;

    if (graph == NULL) {
        printf("Cannot allocate filter graph.");
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

    // printf("Num filters: %d\n", graph->nb_filters);
    // for (int i = 0; i < graph->nb_filters; i++) {
    //     const AVFilterContext *filter = graph->filters[i];
    //     printf("Filter [%d]: %s, inputs: %d, outputs: %D\n", i, filter->name,
    //            filter->nb_inputs, filter->nb_outputs);
    // }

    state->filter->inputs[0] = graph->filters[0];
    state->filter->inputs[1] = graph->filters[1];
    state->filter->output = graph->filters[graph->nb_filters - 1 - 1];

end:
    avfilter_inout_free(&gis);
    avfilter_inout_free(&gos);
    return ret;
}