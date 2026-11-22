/* ========================================================================== */
/*  Cabecalho C gerado automaticamente pelo Compilador Aether (aetherc)       */
/*  Modulo: matematica
/*  Padrao: C99 / C++ compativel com ABI binaria nativa                       */
/* ========================================================================== */

#ifndef AETHER_MATEMATICA_H
#define AETHER_MATEMATICA_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32) || defined(__CYGWIN__)
  #if defined(AETHER_BUILD_DLL)
    #define AETHER_API __declspec(dllexport)
  #else
    #define AETHER_API __declspec(dllimport)
  #endif
#else
  #if defined(AETHER_BUILD_DLL)
    #define AETHER_API __attribute__((visibility("default")))
  #else
    #define AETHER_API
  #endif
#endif

/* --- Tipos e Registros Exportados --- */
typedef struct {
    double x;
    double y;
} Ponto2D;

/* --- Funcoes Exportadas com Chamada C (cdecl) --- */
/*
 * Cria e inicializa uma coordenada 2D
 */
AETHER_API Ponto2D CriarPonto(double x, double y);

/*
 * Soma dois pontos 2D
 */
AETHER_API Ponto2D SomarPontos(Ponto2D p1, Ponto2D p2);

/*
 * Retorna a norma euclidiana ao quadrado de um ponto
 */
AETHER_API double NormaAoQuadrado(Ponto2D p);

/*
 * Funcao simples para somar dois inteiros de 32 bits
 */
AETHER_API int32_t SomarInteiros(int32_t a, int32_t b);

/*
 * Multiplica dois inteiros de 32 bits
 */
AETHER_API int32_t MultiplicarInteiros(int32_t a, int32_t b);

#ifdef __cplusplus
}
#endif

#endif /* AETHER_MATEMATICA_H */
