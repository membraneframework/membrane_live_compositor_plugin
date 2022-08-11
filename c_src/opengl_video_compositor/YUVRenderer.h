#pragma once

#include <glad/gles2.h>

#include <vector>

#include "BasicFBO.h"
#include "NonCopyable.h"
#include "RectVAO.h"
#include "Shader.h"
#include "YUVTexture.h"

/**
 * @brief This class holds all state necessary for rendering planar-YUV-encoded frames
 * 
 */
class YUVRenderer : public NonCopyable {
 public:
  YUVRenderer(GLsizei width, GLsizei height, std::vector<RectVAO> &&vaos,
              Shader &&shader);

  void upload_texture(const char *data, bool upper) const;
  void render_into(std::vector<char> &buffer) const;

  YUVRenderer(YUVRenderer &&) noexcept = default;
  YUVRenderer &operator=(YUVRenderer &&) noexcept = default;

 private:
  GLsizei m_width;
  GLsizei m_height;
  std::vector<RectVAO> m_vaos;
  YUVTexture m_textures[2];
  BasicFBO m_fbos[3];
  Shader m_shader;
};
