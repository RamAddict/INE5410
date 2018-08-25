#include <stdio.h>

//    (pai)
//      |
//   filho_1 

// ~~~ printfs  ~~~
//        filho (ao iniciar): "Processo %d iniciado\n"
//          pai (ao iniciar): "Processo pai iniciado\n"
// pai (após filho terminar): "Filho retornou com código %d,%s encontrou silver\n"
//                            , onde %s é
//                              - ""    , se filho saiu com código 0
//                              - " não" , caso contrário

// Obs:
// - processo pai deve esperar pelo filho
// - filho deve trocar seu binário para executar "grep silver text"
//   + dica: use execlp(char*, char*...)
//   + dica: em "grep silver text",  argv = {"grep", "silver", "text"}

int main(int argc, char** argv) {
    printf("Processo principal iniciado\n");

    // ....
    
    return 0;
}
