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
