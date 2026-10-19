#version 460 core

// Paleta da tela em 4 tons exatos (ver lib/game/paleta_tela.dart): cada
// pixel vira a própria luminosidade e é arredondado pro tom mais próximo,
// como a tela de um portátil clássico.

#include <flutter/runtime_effect.glsl>

// Preenchidos pelo motor: o tamanho e a imagem de entrada do filtro.
uniform vec2 uTamanho;

// Os 4 tons, do mais escuro ao mais claro.
uniform vec4 uTom0;
uniform vec4 uTom1;
uniform vec4 uTom2;
uniform vec4 uTom3;

uniform sampler2D uEntrada;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uTamanho;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  vec4 cor = texture(uEntrada, uv);
  float a = cor.a;
  // A textura vem com alfa pré-multiplicado: desfaz antes de medir o brilho.
  vec3 rgb = a > 0.0 ? cor.rgb / a : vec3(0.0);
  float l = dot(rgb, vec3(0.299, 0.587, 0.114));
  vec3 tom = l < 0.25 ? uTom0.rgb
           : l < 0.5  ? uTom1.rgb
           : l < 0.75 ? uTom2.rgb
           : uTom3.rgb;
  fragColor = vec4(tom * a, a);
}
