#pragma once

#include <glad/glad.h>
#include <vector>

#include "NonCopyable.h"

class BasicFBO : public NonCopyable {
public:
    BasicFBO(unsigned int width, unsigned int height, GLenum internal_format, GLenum format, GLenum type);
    ~BasicFBO();

    void bind() const;
    void read(std::vector<char> &read_buffer) const;
    void read_to_ptr(char *buffer) const;

    [[nodiscard]] GLuint id() const;
    [[nodiscard]] GLuint renderbuffer_id() const;

    BasicFBO(BasicFBO&&) noexcept;
    BasicFBO& operator=(BasicFBO&&) noexcept;
private:
    GLsizei m_width;
    GLsizei m_height;
    GLuint m_id;
    GLuint m_renderbuffer_id;
    GLenum m_internal_format;
    GLenum m_format;
    GLenum m_type;
};