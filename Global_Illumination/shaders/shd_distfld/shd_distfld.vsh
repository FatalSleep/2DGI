//
// Simple passthrough vertex shader
//
attribute vec3 in_Position;
attribute vec2 in_TextureCoord;
varying vec2 in_Coord;
varying vec4 in_Color;

void main() {
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(in_Position, 1.0);
    in_Coord = in_TextureCoord;
}