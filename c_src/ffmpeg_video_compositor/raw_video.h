#include <libavutil/pixfmt.h>

typedef struct RawVideo {
    int width;
    int height;
    enum AVPixelFormat pixel_format;
} RawVideo;

enum AVPixelFormat get_pixel_format(const char *fmt_name);
/*
Returns the specified pixel code.
*/