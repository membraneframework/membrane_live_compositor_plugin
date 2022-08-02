#include "utility.h"

#include <libavutil/error.h>
#include <stdio.h>

/**
 * @brief Print error message to the stderr with formatted error code.
 *
 * @param msg
 * @param error_code
 */
void print_av_error(const char *msg, int error_code) {
  fprintf(stderr, "%s: %s\n", msg, av_err2str(error_code));
}
