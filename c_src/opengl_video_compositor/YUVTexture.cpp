#include "YUVTexture.h"

/**
 * @brief Construct a new YUVTexture object
 * 
 * @param width Width (in pixels)
 * @param height Height (in pixels)
 */
YUVTexture::YUVTexture(GLsizei width, GLsizei height)
    : m_width{width}, m_height{height} {
  glGenTextures(3, m_textures);

  for (GLuint texture : m_textures) {
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  }
}

/**
 * @brief Bind these textures for sampling
 * 
 */
void YUVTexture::bind() const {
  for (int i = 0; i < 3; ++i) {
    glActiveTexture(GL_TEXTURE0 + i);
    glBindTexture(GL_TEXTURE_2D, m_textures[i]);
  }
}

/**
 * @brief Upload the data pointed to by `data`. 
 * 
 * @param data Pointer to the frame data. This function doesn't check anything 
 *             about this pointer and assumes it points to a valid YUV frame 
 *             with a correct resolution.
 */
void YUVTexture::load(const char *data) const {
  bind();
  auto pixel_amount = m_width * m_height;
  glActiveTexture(GL_TEXTURE0);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, m_width, m_height, 0, GL_RED,
               GL_UNSIGNED_BYTE, data);

  glActiveTexture(GL_TEXTURE1);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, m_width / 2, m_height / 2, 0, GL_RED,
               GL_UNSIGNED_BYTE, data + pixel_amount);

  glActiveTexture(GL_TEXTURE2);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, m_width / 2, m_height / 2, 0, GL_RED,
               GL_UNSIGNED_BYTE, data + pixel_amount + pixel_amount / 4);
}

YUVTexture::~YUVTexture() {
  if (m_textures[0] != 0) {
    glDeleteTextures(3, m_textures);
  }
}

YUVTexture::YUVTexture(YUVTexture &&other) noexcept
    : m_width(other.m_width), m_height(other.m_height) {
  for (int i = 0; i < 3; ++i) {
    m_textures[i] = other.m_textures[i];
    other.m_textures[i] = 0;
  }
}

YUVTexture &YUVTexture::operator=(YUVTexture &&other) noexcept {
  if (this != &other) {
    m_width = other.m_width;
    m_height = other.m_height;
    for (int i = 0; i < 3; ++i) {
      m_textures[i] = other.m_textures[i];
      other.m_textures[i] = 0;
    }
  }
  return *this;
}
