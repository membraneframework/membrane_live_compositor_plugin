#include "raw_video.h"

#include <string.h>

/**
 * @brief Returns the specified pixel code.
 *
 * @param fmt_name Pixel format string
 * @return Pixel format code
 */
enum AVPixelFormat get_pixel_format(const char *fmt_name) {
  enum AVPixelFormat pix_fmt = AV_PIX_FMT_NONE;
  if (strcmp(fmt_name, "I420") == 0) {
    pix_fmt = AV_PIX_FMT_YUV420P;
  } else if (strcmp(fmt_name, "I422") == 0) {
    pix_fmt = AV_PIX_FMT_YUV422P;
  } else if (strcmp(fmt_name, "I444") == 0) {
    pix_fmt = AV_PIX_FMT_YUV444P;
  }
  return pix_fmt;
}

/**
 * @brief Init the raw video with the given parameters
 *
 * @param raw_video Destination video
 * @param width Video width
 * @param height Video height
 * @param pixel_format_name Pixel format name given in a string. It will be
 * converted into the corresponding enum code
 * @return Return code. Return 0 on success, negative value otherwise
 */
int init_raw_video(RawVideo *raw_video, int width, int height,
                   const char *pixel_format_name) {
  int pixel_format = get_pixel_format(pixel_format_name);
  if (pixel_format < 0) {
    return -1;
  }
  raw_video->width = width;
  raw_video->height = height;
  raw_video->pixel_format = pixel_format;
  return 0;
}
