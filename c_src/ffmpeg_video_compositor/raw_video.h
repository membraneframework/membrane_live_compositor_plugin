#include <libavutil/pixfmt.h>

typedef struct RawVideo {
    int width;
    int height;
    enum AVPixelFormat pixel_format;
} RawVideo;

/**
 * @brief Returns the specified pixel code.
 *
 * @param fmt_name Pixel format string
 * @return Pixel format code
 */
enum AVPixelFormat get_pixel_format(const char *fmt_name);
