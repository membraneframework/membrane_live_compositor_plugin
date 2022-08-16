#include "BasicFBO.h"

#include <iostream>

/**
 * @brief Construct a new Basic Framebuffer Object:
 * 
 * @param width Width of the buffer (in pixels)
 * @param height Height of the buffer (in pixels)
 * @param internal_format Internal format of the buffer (e.g. `GL_R8` or `GL_RGB8`)
 * @param format Format that the data read form this buffer will have (e.g. `GL_RED` or `GL_RGB`)
 * @param type Type that the data read form this buffer will have (e.g. `GL_UNSIGNED_INT`)
 */
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

/**
 * @brief Bind this framebuffer object for being drawn into
 * 
 */
void BasicFBO::bind() const {
  glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_id);
  GLenum color_attachment = GL_COLOR_ATTACHMENT0;
  glDrawBuffers(1, &color_attachment);
  glViewport(0, 0, m_width, m_height);
}

/**
 * @brief Read the contents of this framebuffer into a vector. 
 *        This function also ensures the vector has enough capacity.
 * 
 * @param buffer Data will be copied into this vector
 */
void BasicFBO::read(std::vector<char> &buffer) const {
  buffer.reserve(m_width * m_height);
  read_to_ptr(buffer.data());
}

/**
 * @brief Read the contents of this framebuffer into an array pointed to by `buffer`
 * 
 * @param buffer Target pointer
 */
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
