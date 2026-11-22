#include <stdio.h>
#include <assert.h>
#include "include/matematica.h"

int main(void) {
    printf("[C Client] Testando consumo do cabecalho e DLL gerados pelo Aether...\n");

    int32_t soma = SomarInteiros(100, 250);
    printf("[C Client] SomarInteiros(100, 250) = %d\n", soma);
    assert(soma == 350);

    int32_t mult = MultiplicarInteiros(8, 9);
    printf("[C Client] MultiplicarInteiros(8, 9) = %d\n", mult);
    assert(mult == 72);

    Ponto2D p1 = CriarPonto(3.0, 4.0);
    Ponto2D p2 = CriarPonto(5.0, 6.0);
    Ponto2D p3 = SomarPontos(p1, p2);
    printf("[C Client] P3: (%.2f, %.2f)\n", p3.x, p3.y);
    assert(p3.x == 8.0 && p3.y == 10.0);

    double norma = NormaAoQuadrado(p1);
    printf("[C Client] NormaAoQuadrado(p1) = %.2f\n", norma);
    assert(norma == 25.0);

    printf(">>> SUCESSO! Cliente C consumiu a DLL e cabecalho .h do Aether com exito! <<<\n");
    return 0;
}
