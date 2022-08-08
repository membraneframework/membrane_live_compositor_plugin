R"(#version 300 es
precision mediump float;
out vec4 FragColor;
in vec2 texCoord;

uniform sampler2D texture1;

void main() {
  FragColor = texture(texture1, texCoord);
}
)"
