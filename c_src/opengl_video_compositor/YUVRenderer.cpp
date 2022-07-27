#include "YUVRenderer.h"

YUVRenderer::YUVRenderer(GLsizei width, GLsizei height, std::vector<RectVAO> &&vaos, Shader &&shader)
    : m_width{width}
    , m_height{height}
    , m_vaos{std::move(vaos)}
    , m_textures{YUVTexture{width, height}, YUVTexture{width, height}}
    , m_fbos {
        BasicFBO(width, height * 2, GL_R8, GL_RED, GL_UNSIGNED_BYTE),
        BasicFBO(width / 2, height, GL_R8, GL_RED, GL_UNSIGNED_BYTE),
        BasicFBO(width / 2, height, GL_R8, GL_RED, GL_UNSIGNED_BYTE)
        }
    , m_shader{std::move(shader)} {
}

void YUVRenderer::upload_texture(const char *data, bool upper) const {
    int i = upper ? 0 : 1;
    m_textures[i].load(data);
}

void YUVRenderer::render_into(std::vector<char> &buffer) const {
    m_shader.use();

    for(int channel = 0; channel < 3; ++channel) {
        m_fbos[channel].bind();
        m_shader.setInt("texture1", channel);
        for(int stream = 0; stream < 2; ++stream) {

            m_vaos[stream].bind();
            m_textures[stream].bind();
            m_vaos[stream].draw();
        }

        int offset = 0;
        if(channel == 1) offset = m_width * m_height * 2;
        if(channel == 2) offset = m_width * m_height * 5 / 2;
        m_fbos[channel].read_to_ptr(buffer.data() + offset);

    }
}
