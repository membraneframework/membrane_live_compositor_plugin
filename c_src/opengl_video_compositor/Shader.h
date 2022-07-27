#pragma once

#include <string>

#include "NonCopyable.h"

class Shader : public NonCopyable {
public:
    unsigned int m_id;

    static Shader from_files(const char *vertexPath, const char *fragmentPath);
    Shader(const std::string &vertex_code, const std::string &fragment_code);

    void use() const;

    void setBool(const std::string &name, bool value) const;
    void setInt(const std::string &name, int value) const;
    void setFloat(const std::string &name, float value) const;
    void setMat4(const std::string &name, const float* value) const;

    bool check_if_compiled_correctly(unsigned int shader, std::string name);

    bool check_if_linked_correctly(unsigned int program, std::string name);

    ~Shader();
    Shader(Shader&&) noexcept;
    Shader& operator=(Shader&&) noexcept;
};