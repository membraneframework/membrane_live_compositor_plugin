#pragma once

#include <glad/gles2.h>

#include <vector>

#include "NonCopyable.h"

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
