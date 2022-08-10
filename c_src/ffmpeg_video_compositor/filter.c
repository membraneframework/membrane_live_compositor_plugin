#include "filter.h"

/**
 * @brief Creates a filter description string in an FFmpeg format and stores it
 * in the given string.
 *
 * @param filter_str Description destination (buffer)
 * @param filter_size Maximum size of the filter description (buffer size)
 * @param videos Array of input videos.
 * @param positions Array for positions of input videos.
 * @param n_videos Size of the videos array
 * @return Number of characters written to the buffer
 */
int get_filter_description(char *filter_str, int filter_size, RawVideo videos[],
                           Vec2 positions[], int n_videos);

/**
 * @brief Creates a filter graph from the string description and stores it in
 * the given filter.
 *
 * @param filters_descr String description of the filter graph. This should
 * follow FFmpeg filter documentation.
 * @param filter  Pointer to the filter graph.
 * @param n_inputs  Number of input videos.
 * @return Return code. Return 0 on success, a negative value on failure.
 */
int init_filters_graph(const char *filter_str, FilterState *filter,
                       int n_inputs);

/**
 * @brief Free the memory of the filter state and sets its members to proper
 * values
 *
 *
 * @param filter Target filter state pointer
 */
void free_filter_state(FilterState *filter);

/**
 * @brief Append a header of the filter description to the string (buffer).
 * Creates \p n_videos input nodes with output pads named [in_1], [in_2], ..,
 * [in_ \p n_videos].
 *
 * @param filter_str Description destination string (buffer)
 * @param filter_size Remaining size of the buffer
 * @param videos Array of input videos.
 * @param n_videos Size of the videos array
 * @return Number of characters written to the buffer
 */
static int append_input_nodes_filter_string(char *filter_str, int filter_size,
                                            RawVideo videos[], int n_videos);

/**
 * @brief Creates a filter parameters description string in an FFmpeg format of
 * the input video
 *
 * @param filter_str Description destination (buffer)
 * @param filter_size Maximum size of the filter description (buffer size)
 * @param video Video pointer
 * @param input_pad_idx Index of the corresponding input pad
 * @return Number of characters written to the buffer
 */
static int get_input_video_description(char *filter_str, int filter_size,
                                       RawVideo *video, int input_pad_idx);

/**
 * @brief Append a main filter description (transformation graph) to the string
 * (buffer)
 *
 * @param filter_str Description destination string (buffer)
 * @param filter_size Remaining size of the buffer
 * @param videos Input videos array
 * @param positions Positions of the input videos
 * @return Number of characters written to the buffer
 */
static int apply_filters_options_string(char *filter_str, int filter_size,
                                        RawVideo videos[], Vec2 positions[],
                                        int n_videos);

/**
 * @brief Append a footer filter description to the string
 * (buffer).
 *
 * @param filter_str Description destination string (buffer)
 * @param filter_size Remaining size of the buffer
 * @return Number of characters written to the buffer
 */
static int finish_filter_string(char *filter_str, int filter_size);

/**
 * @brief Get the size of the minimum rectangle containing all the videos, on
 * the given positions
 *
 * @param videos Array of videos
 * @param positions Corresponding positions of the videos
 * @param n_videos Number of videos
 * @return Size (width, height) of the minimum rectangle containing all the
 * videos
 */
Vec2 get_max_dimension(RawVideo videos[], Vec2 positions[], int n_videos);

////////////////////////////////////////////////////////////////////////////////////////////////

int get_filter_description(char *filter_str, int filter_size, RawVideo videos[],
                           Vec2 positions[], int n_videos) {
  int filter_end = 0;

  filter_end += append_input_nodes_filter_string(
      filter_str + filter_end, filter_size - filter_end, videos, n_videos);
  filter_end += apply_filters_options_string(filter_str + filter_end,
                                             filter_size - filter_end, videos,
                                             positions, n_videos);
  filter_end +=
      finish_filter_string(filter_str + filter_end, filter_size - filter_end);
  return filter_end;
}

static int append_input_nodes_filter_string(char *filter_str, int filter_size,
                                            RawVideo videos[], int n_videos) {
  int filter_end = 0;
  for (int i = 0; i < n_videos; ++i) {
    RawVideo *video = &videos[i];
    const int input_pad_idx = i + 1;
    filter_end += get_input_video_description(filter_str + filter_end,
                                              filter_size - filter_end, video,
                                              input_pad_idx);
  }
  return filter_end;
}

static int get_input_video_description(char *filter_str, int filter_size,
                                       RawVideo *video, int input_pad_idx) {
  static const char *video_description_format =
      "buffer="
      "video_size=%dx%d"
      ":pix_fmt=%d"
      ":time_base=%d/%d"
      "[in_%d];\n";

  const int time_base_num = video->framerate_den;
  const int time_base_den = video->framerate_num;

  return snprintf(filter_str, filter_size, video_description_format,
                  video->width, video->height, video->pixel_format,
                  time_base_num, time_base_den, input_pad_idx);
}

static int apply_filters_options_string(char *filter_str, int filter_size,
                                        RawVideo videos[], Vec2 positions[],
                                        int n_videos) {
  int filter_end = 0;
  Vec2 dimensions = get_max_dimension(videos, positions, n_videos);
  int total_width = dimensions.x, total_height = dimensions.y;

  filter_end += snprintf(filter_str + filter_end, filter_size - filter_end,
                         "[in_1]pad=%d:%d:%d:%d", total_width, total_height,
                         positions[0].x, positions[0].y);

  for (int i = 1; i < n_videos; ++i) {
    Vec2 pos = positions[i];
    filter_end += snprintf(filter_str + filter_end, filter_size - filter_end,
                           "[mid_%d];\n[mid_%d][in_%d] overlay=x=%d:y=%d", i, i,
                           i + 1, pos.x, pos.y);
  }
  return filter_end;
}

Vec2 get_max_dimension(RawVideo videos[], Vec2 positions[], int n_videos) {
  int width = 0, height = 0;
  for (int i = 0; i < n_videos; i++) {
    width = max(width, videos[i].width + positions[i].x);
    height = max(height, videos[i].height + positions[i].y);
  }
  Vec2 dims = {width, height};
  return dims;
}

static int finish_filter_string(char *filter_str, int filter_size) {
  int filter_end = 0;

  filter_end += snprintf(filter_str + filter_end, filter_size - filter_end,
                         "%s", "[out];\n[out] buffersink");
  return filter_end;
}

int init_filters_graph(const char *filter_str, FilterState *filter,
                       int n_inputs) {
  int ret = 0;
  filter->graph = avfilter_graph_alloc();
  AVFilterGraph *graph = filter->graph;

  if (graph == NULL) {
    fprintf(stderr, "Cannot allocate filter graph.");
    return -1;
  }
  filter->inputs = NULL;
  filter->inputs = malloc(n_inputs * sizeof(*filter->inputs));
  filter->n_inputs = n_inputs;

  if (filter->inputs == NULL) {
    fprintf(stderr, "Cannot allocate filter inputs.");
    ret = -1;
    goto end;
  }

  AVFilterInOut *gis = NULL;
  AVFilterInOut *gos = NULL;

  ret = avfilter_graph_parse2(graph, filter_str, &gis, &gos);
  if (ret < 0) {
    print_av_error("Cannot parse graph.", ret);
    goto end;
  }

  ret = avfilter_graph_config(graph, NULL);
  if (ret < 0) {
    print_av_error("Cannot configure graph.", ret);
    goto end;
  }

  for (unsigned i = 0, idx = 0; i < graph->nb_filters; i++) {
    AVFilterContext *filter_ctx = graph->filters[i];
    if (filter_ctx->nb_inputs == 0) {
      filter->inputs[idx] = filter_ctx;
      idx++;
    }
    if (idx == filter->n_inputs) {
      break;
    }
  }
  for (unsigned i = 0; i < graph->nb_filters; i++) {
    AVFilterContext *output = graph->filters[i];
    if (output->nb_outputs == 0) {
      filter->output = output;
      break;
    }
  }

end:
  avfilter_inout_free(&gis);
  avfilter_inout_free(&gos);
  return ret;
}

void free_filter_state(FilterState *filter) {
  if (filter->graph != NULL) {
    avfilter_graph_free(&filter->graph);
  }
  free(filter->inputs);
  filter->output = NULL;
}
