#include "Shader.h"

#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

#include "glad/gles2.h"

/**
 * @brief Construct a new Shader object from vertex & fragment shader source code.
 *        This will print out an error log if the shaders fail to link/compile
 * 
 * @param vertex_code Source code for the vertex shader
 * @param fragment_code Source code for the fragment shader
 */
Shader::Shader(const char *vertex_code, const char *fragment_code) {
  const char *vertexCodeCStr = vertex_code;
  const char *fragmentCodeCStr = fragment_code;

  unsigned int vertexShaderId = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vertexShaderId, 1, &vertexCodeCStr, nullptr);
  glCompileShader(vertexShaderId);

  check_if_compiled_correctly(vertexShaderId, "vertex");

  unsigned int fragmentShaderId = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fragmentShaderId, 1, &fragmentCodeCStr, nullptr);
  glCompileShader(fragmentShaderId);
  check_if_compiled_correctly(fragmentShaderId, "fragment");

  m_id = glCreateProgram();
  glAttachShader(m_id, vertexShaderId);
  glAttachShader(m_id, fragmentShaderId);
  glLinkProgram(m_id);

  check_if_linked_correctly(m_id, "program");

  glDeleteShader(vertexShaderId);
  glDeleteShader(fragmentShaderId);
}

/**
 * @brief Use this shader program.
 * 
 */
void Shader::use() const { glUseProgram(m_id); }

/**
 * @brief Set a boolean uniform in this shader program
 * 
 * @param name Name of the uniform to set
 * @param value Value to set the uniform to
 */
void Shader::setBool(const std::string &name, bool value) const {
  glUniform1i(glGetUniformLocation(m_id, name.c_str()), (int)value);
}

/**
 * @brief Set an integer uniform in this shader program
 * 
 * @param name Name of the uniform to set
 * @param value Value to set the uniform to
 */
void Shader::setInt(const std::string &name, int value) const {
  glUniform1i(glGetUniformLocation(m_id, name.c_str()), value);
}

/**
 * @brief Set a float uniform in this shader program
 * 
 * @param name Name of the uniform to set
 * @param value Value to set the uniform to
 */
void Shader::setFloat(const std::string &name, float value) const {
  glUniform1f(glGetUniformLocation(m_id, name.c_str()), value);
}

/**
 * @brief Set a 4x4 matrix uniform in this shader program
 * 
 * @param name Name of the uniform to set
 * @param value Value to set the uniform to
 */
void Shader::setMat4(const std::string &name, const float *value) const {
  glUniformMatrix4fv(glGetUniformLocation(m_id, name.c_str()), 1, GL_FALSE,
                     value);
}

bool Shader::check_if_compiled_correctly(unsigned int shader,
                                         std::string name) {
  int success;
  char infoLog[512];
  glGetShaderiv(shader, GL_COMPILE_STATUS, &success);

  if (!success) {
    glGetShaderInfoLog(shader, 512, NULL, infoLog);
    std::cout << "Error in " << name << " shader compilation:\n"
              << infoLog << std::endl;
  }

  return success;
}

bool Shader::check_if_linked_correctly(unsigned int program, std::string name) {
  int success;
  char infoLog[512];
  glGetProgramiv(program, GL_LINK_STATUS, &success);

  if (!success) {
    glGetProgramInfoLog(program, 512, NULL, infoLog);
    std::cout << "Error in " << name << " linking:\n" << infoLog << std::endl;
  }

  return success;
}

Shader::~Shader() {
  if (m_id != 0) glDeleteProgram(m_id);
}

Shader::Shader(Shader &&other) noexcept : m_id(other.m_id) { other.m_id = 0; }

Shader &Shader::operator=(Shader &&other) noexcept {
  if (this != &other) {
    this->m_id = other.m_id;
    other.m_id = 0;
  }
  return *this;
}
