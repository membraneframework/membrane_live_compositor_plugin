#include "filter.h"

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

int init_filters(const char *filters_descr, VState *state) {
    char args[512];
    int ret = 0;
    const AVFilter *buffersrc = avfilter_get_by_name("buffer");
    const AVFilter *buffersink = avfilter_get_by_name("buffersink");
    AVFilterInOut *outputs = avfilter_inout_alloc();
    AVFilterInOut *inputs = avfilter_inout_alloc();
    enum AVPixelFormat pix_fmts[] = {state->pixel_format, AV_PIX_FMT_NONE};
    state->filter_graph = avfilter_graph_alloc();

    if (!buffersrc || !buffersink || !outputs || !inputs ||
        !state->filter_graph) {
        ret = AVERROR(ENOMEM);
        goto exit_init_filter;
    }
    snprintf(args, sizeof(args), "video_size=%dx%d:pix_fmt=%d:time_base=1/1",
             state->width, state->height, state->pixel_format);

    ret = avfilter_graph_create_filter(&state->buffersrc_ctx, buffersrc, "in",
                                       args, NULL, state->filter_graph);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot create buffer source\n");
        goto exit_init_filter;
    }

    ret = avfilter_graph_create_filter(&state->buffersink_ctx, buffersink,
                                       "out", NULL, NULL, state->filter_graph);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot create buffer sink\n");
        goto exit_init_filter;
    }

    ret = av_opt_set_int_list(state->buffersink_ctx, "pix_fmts", pix_fmts,
                              AV_PIX_FMT_NONE, AV_OPT_SEARCH_CHILDREN);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot set output pixel format\n");
        goto exit_init_filter;
    }

    outputs->name = av_strdup("in");
    outputs->filter_ctx = state->buffersrc_ctx;
    outputs->pad_idx = 0;
    outputs->next = NULL;

    inputs->name = av_strdup("out");
    inputs->filter_ctx = state->buffersink_ctx;
    inputs->pad_idx = 0;
    inputs->next = NULL;

    if ((ret = avfilter_graph_parse_ptr(state->filter_graph, filters_descr,
                                        &inputs, &outputs, NULL)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "graph creating error\n");
        goto exit_init_filter;
    }
    if ((ret = avfilter_graph_config(state->filter_graph, NULL)) < 0)
        goto exit_init_filter;

exit_init_filter:
    avfilter_inout_free(&inputs);
    avfilter_inout_free(&outputs);

    return ret;
}
