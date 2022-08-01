#pragma once

#include <vector>
#include <glad/glad.h>

#include "NonCopyable.h"

class RectVAO : public NonCopyable {
public:
    RectVAO(const std::vector<float> &vertices, const std::vector<unsigned int> &indices);
    ~RectVAO();

    RectVAO(RectVAO&&) noexcept;
    RectVAO& operator=(RectVAO&&) noexcept;

    void bind() const;
    void draw() const;
private:
    GLuint m_id;
    GLuint m_vertex_buffer_id;
    GLuint m_elements_buffer_id;
    std::size_t m_indices_amount;
};