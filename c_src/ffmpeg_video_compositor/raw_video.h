#pragma once

#include <libavutil/pixfmt.h>

typedef struct RawVideo {
  int width;
  int height;
  int framerate_num;
  int framerate_den;
  enum AVPixelFormat pixel_format;
} RawVideo;

enum AVPixelFormat get_pixel_format(const char *fmt_name);

int init_raw_video(RawVideo *raw_video, int width, int height,
                   int framerate_num, int framerate_den,
                   const char *pixel_format_name);
