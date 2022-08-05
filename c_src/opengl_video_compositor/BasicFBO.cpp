#include "BasicFBO.h"

#include <iostream>

BasicFBO::BasicFBO(unsigned int width, unsigned int height,
                   GLenum internal_format, GLenum format, GLenum type)
    : m_width(width),
      m_height(height),
      m_id(0),
      m_renderbuffer_id(0),
      m_internal_format(internal_format),
      m_format(format),
      m_type(type) {
  glGenFramebuffers(1, &m_id);
  glBindFramebuffer(GL_FRAMEBUFFER, m_id);

  glGenRenderbuffers(1, &m_renderbuffer_id);
  glBindRenderbuffer(GL_RENDERBUFFER, m_renderbuffer_id);
  glRenderbufferStorage(GL_RENDERBUFFER, internal_format, m_width, m_height);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                            GL_RENDERBUFFER, m_renderbuffer_id);

  auto status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
  if (status != GL_FRAMEBUFFER_COMPLETE) {
    std::cout << "fbo not complete" << std::endl;
    switch (status) {
      case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
        std::cout << "incomplete attachment" << std::endl;
        break;
      case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
        std::cout << "incomplete missing attachment" << std::endl;
        break;
      case GL_FRAMEBUFFER_UNSUPPORTED:
        std::cout << "fb unsupported" << std::endl;
        break;
      default:
        std::cout << "uncaught" << std::endl;
    }
  }
}

BasicFBO::~BasicFBO() {
  if (m_id != 0) glDeleteFramebuffers(1, &m_id);
  if (m_renderbuffer_id != 0) glDeleteRenderbuffers(1, &m_renderbuffer_id);
}

void BasicFBO::bind() const {
  glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_id);
  // glDrawBuffer(GL_COLOR_ATTACHMENT0);
  glViewport(0, 0, m_width, m_height);
}

void BasicFBO::read(std::vector<char> &buffer) const {
  buffer.reserve(m_width * m_height);
  read_to_ptr(buffer.data());
}

void BasicFBO::read_to_ptr(char *buffer) const {
  glBindFramebuffer(GL_READ_FRAMEBUFFER, m_id);
  glReadBuffer(GL_COLOR_ATTACHMENT0);

  glReadPixels(0, 0, m_width, m_height, m_format, m_type, buffer);
}

GLuint BasicFBO::id() const { return m_id; }

GLuint BasicFBO::renderbuffer_id() const { return m_renderbuffer_id; }

BasicFBO::BasicFBO(BasicFBO &&other) noexcept
    : m_width(other.m_width),
      m_height(other.m_height),
      m_id(other.m_id),
      m_renderbuffer_id(other.m_renderbuffer_id),
      m_internal_format(other.m_internal_format),
      m_format(other.m_format),
      m_type(other.m_type) {
  other.m_id = 0;
  other.m_renderbuffer_id = 0;
}

BasicFBO &BasicFBO::operator=(BasicFBO &&other) noexcept {
  if (this != &other) {
    m_id = other.m_id;
    m_height = other.m_height;
    m_width = other.m_width;
    m_renderbuffer_id = other.m_renderbuffer_id;
    m_format = other.m_format;
    m_type = other.m_type;
    m_internal_format = other.m_internal_format;

    other.m_id = 0;
    other.m_renderbuffer_id = 0;
  }

  return *this;
}
