
typedef struct Vec2 {
  int x, y;
} Vec2;

#define SIZE(x) ((int)(sizeof(x) / sizeof(x[0])))

#define N_MAX_VIDEOS 64

void print_av_error(const char *msg, int error_code);
