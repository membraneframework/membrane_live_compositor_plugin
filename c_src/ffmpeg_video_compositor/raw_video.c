
#include "raw_video.h"

AVPixelFormat get_pixel_format(const char *fmt_name) {
    AVPixelFormat pix_fmt = AV_PIX_FMT_NONE;
    if (strcmp(fmt_name, "I420") == 0) {
        pix_fmt = AV_PIX_FMT_YUV420P;
    } else if (strcmp(fmt_name, "I422") == 0) {
        pix_fmt = AV_PIX_FMT_YUV422P;
    } else if (strcmp(fmt_name, "I444") == 0) {
        pix_fmt = AV_PIX_FMT_YUV444P;
    }
    return pix_fmt;
}