#include "Compositor.h"

#include <glad/gles2.h>

#include <iostream>

#include "RectVAO.h"
#include "Shader.h"

const char *vertex_code =
#include "shaders/vertex.glsl"
    ;

const char *fragment_code =
#include "shaders/fragment.glsl"
    ;

const std::vector<float> vertices_bot = {
    1.0f,  0.0f,  0.0f, 1.0f, 1.0f,  // 0 top-right
    -1.0f, 0.0f,  0.0f, 0.0f, 1.0f,  // 1 top-left
    -1.0f, -1.0f, 0.0f, 0.0f, 0.0f,  // 2 bot-left
    1.0f,  -1.0f, 0.0f, 1.0f, 0.0f,  // 3 bot-right
};

const std::vector<float> vertices_top = {
    1.0f,  1.0f, 0.0f, 1.0f, 1.0f,  // 0 top-right
    -1.0f, 1.0f, 0.0f, 0.0f, 1.0f,  // 1 top-left
    -1.0f, 0.0f, 0.0f, 0.0f, 0.0f,  // 2 bot-left
    1.0f,  0.0f, 0.0f, 1.0f, 0.0f,  // 3 bot-right
};

const std::vector<unsigned int> indices = {0, 1, 3, 1, 2, 3};

/**
 * @brief Construct a new Compositor object capable of compositing
 *        two videos, one above the other.
 * 
 * @param width Width of the input videos
 * @param height Height of the input videos
 */
Compositor::Compositor(GLsizei width, GLsizei height)
    : m_in_width(width),
      m_in_height(height),
      m_out_width(width),
      m_out_height(2 * height) {
  auto shader = Shader(vertex_code, fragment_code);
  std::vector<RectVAO> vaos;
  vaos.emplace_back(vertices_top, indices);
  vaos.emplace_back(vertices_bot, indices);

  m_renderer = {width, height, std::move(vaos), std::move(shader)};
}

/**
 * @brief Joins two frames and writes the result into a vector
 * 
 * @param upper Input frame for the video located higher in the output
 * @param lower Input frame for the video located lower in the output
 * @param buffer A buffer for the resulting data. This will be resized 
 *               to hold the whole frame
 */
void Compositor::join_frames(char *upper, char *lower,
                             std::vector<char> &buffer) {
  m_renderer->upload_texture(upper, true);
  m_renderer->upload_texture(lower, false);
  buffer.resize(m_out_width * m_out_height * 3 / 2);
  m_renderer->render_into(buffer);
}

unsigned int Compositor::in_width() { return m_in_width; }

unsigned int Compositor::in_height() { return m_in_height; }

unsigned int Compositor::out_width() { return m_out_width; }

unsigned int Compositor::out_height() { return m_out_height; }
