#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <stdio.h>
#include <string.h>
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
    int son = fork();
    if (son == 0) {
        printf("processo %d iniciado\n", getpid());
        fflush(stdout);
        execlp("grep", "grep", "silver","text", (char *)NULL);

    } else {
        int status;
        waitpid(son, &status, 0);
        if (status == 0) {
            printf("Filho retornou com código %d, encontrou silver\n",status);
        } else {
            printf("Filho retornou com código %d, não encontrou silver\n", WEXITSTATUS(status));
        }
    }
    return 0;
}