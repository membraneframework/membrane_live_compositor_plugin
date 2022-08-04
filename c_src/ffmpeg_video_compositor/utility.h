
typedef struct Vec2 {
  int x, y;
} Vec2;

/**
 * @brief Returns the number of elements in the statically allocated array.
 *
 * @param array Statically allocated array
 */
#define SIZE(array) ((int)(sizeof(array) / sizeof(*array)))

/**
 * @brief Returns the maximum of two numbers
 *
 * @param a 
 * @param b 
 */
#define max(a, b)           \
  ({                        \
    __typeof__(a) _a = (a); \
    __typeof__(b) _b = (b); \
    _a > _b ? _a : _b;      \
  })

#define N_MAX_VIDEOS 64

void print_av_error(const char *msg, int error_code);
