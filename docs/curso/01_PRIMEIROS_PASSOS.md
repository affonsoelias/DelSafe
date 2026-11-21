# Lição 1: Primeiros Passos e Estrutura no Aether

Nesta primeira lição, você aprenderá como um programa Aether é organizado, como declarar módulos e como exibir mensagens no terminal.

---

## 1. O Formato de um Arquivo `.aeth`

Todo arquivo de código no Aether começa declarando a qual **módulo** ele pertence, seguido pelas suas definições e pelo ponto de entrada principal:

```pascal
module OlaMundo;

program Main;
begin
    PrintLn("Ola, Mundo do Aether!");
    PrintLn("Compilando nativamente no Windows, Linux e macOS.");
end.
```

### O que significa cada parte:
- **`module OlaMundo;`**: Define o nome do módulo. O nome deve começar com letra maiúscula (estilo `PascalCase`).
- **`program Main;`**: Declara o bloco principal de execução do aplicativo (o ponto de entrada onde o programa começa a rodar).
- **`begin ... end.`**: Delimita o bloco do programa principal. Note o ponto final `.` no último `end.`, mantendo a tradição clássica do Pascal para indicar o fim do arquivo executável.
- **`PrintLn(...)`**: Função nativa para imprimir uma linha no terminal (com quebra de linha automática no final).

---

## 2. Compilando e Executando

Salve o código acima em um arquivo chamado `ola.aeth` e abra o terminal na pasta onde está o arquivo:

### Compilando via Backend Pascal (Padrão):
```bash
aetherc ola.aeth
```
O compilador fará as checagens estáticas e gerará `ola.exe`.

Para rodar:
```bash
./ola.exe
```

### Compilando via Backend C (MSYS2 GCC):
Se preferir gerar código nativo através do GCC:
```bash
aetherc ola.aeth --target=c
```

---

## 3. Comentários no Código

No Aether, você pode documentar seu código com clareza usando dois formatos:

```pascal
// Este e um comentario de uma unica linha.

{ Este e um comentario de bloco estilo Pascal
  que pode ocupar varias linhas sem problemas. }

/* Este tambem e um comentario multilinha estilo C */
```

---

## 4. Exercício Prático
1. Modifique o programa para imprimir o seu nome e a sua linguagem de programação favorita anterior.
2. Compile usando `aetherc` e execute o binário.

Quando estiver pronto, avance para a **[Lição 2: Variáveis e Sistema de Tipos](file:///c:/Users/Pichau/Documents/aether/docs/curso/02_VARIAVEIS_E_TIPOS.md)**!
