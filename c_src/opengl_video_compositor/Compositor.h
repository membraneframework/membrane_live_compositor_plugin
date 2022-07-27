#pragma once

#include <vector>
#include <optional>

#include "YUVRenderer.h"

class Compositor {
public:
    Compositor(GLsizei width, GLsizei height);
    void join_frames(char *upper, char *lower, std::vector<char> &buffer);
    unsigned int in_width();
    unsigned int in_height();
    unsigned int out_width();
    unsigned int out_height();
private:
    unsigned int m_in_width, m_in_height, m_out_width, m_out_height;
    std::optional<YUVRenderer> m_renderer;
};

