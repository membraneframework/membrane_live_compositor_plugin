#pragma once

#include <glad/gles2.h>

#include <vector>

#include "NonCopyable.h"

/**
 * @brief This class is an abstraction for a Vertex Array Object representing a rectangle
 *        https://www.khronos.org/opengl/wiki/Vertex_Specification#Vertex_Array_Object
 * 
 */
class RectVAO : public NonCopyable {
 public:
  RectVAO(const std::vector<float> &vertices,
          const std::vector<unsigned int> &indices);
  ~RectVAO();

  RectVAO(RectVAO &&) noexcept;
  RectVAO &operator=(RectVAO &&) noexcept;

  void bind() const;
  void draw() const;

 private:
  GLuint m_id;
  GLuint m_vertex_buffer_id;
  GLuint m_elements_buffer_id;
  std::size_t m_indices_amount;
};
