#pragma once

#include <glad/gles2.h>

#include <vector>

#include "NonCopyable.h"

/**
 * @brief This class is an abstraction for a bundle of OpenGL Textures used for rendering a planar YUV images
 *        We have a separate texture for each plane.
 *        https://www.khronos.org/opengl/wiki/Texture
 * 
 */
class YUVTexture : public NonCopyable {
 public:
  YUVTexture(GLsizei width, GLsizei height);

  void bind() const;
  void load(const char* data) const;

  ~YUVTexture();
  YUVTexture(YUVTexture&&) noexcept;
  YUVTexture& operator=(YUVTexture&&) noexcept;

 private:
  GLuint m_textures[3]{};
  GLsizei m_width, m_height;
};
