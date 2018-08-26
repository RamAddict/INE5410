#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <stdio.h>
#include <string.h>
//                          (principal)
//                               |
//              +----------------+--------------+
//              |                               |
//           filho_1                         filho_2
//              |                               |
//    +---------+-----------+          +--------+--------+
//    |         |           |          |        |        |
// neto_1_1  neto_1_2  neto_1_3     neto_2_1 neto_2_2 neto_2_3

// ~~~ printfs  ~~~
//      principal (ao finalizar): "Processo principal %d finalizado\n"
// filhos e netos (ao finalizar): "Processo %d finalizado\n"
//    filhos e netos (ao inciar): "Processo %d, filho de %d\n"

// Obs:
// - netos devem esperar 5 segundos antes de imprmir a mensagem de finalizado (e terminar)
// - pais devem esperar pelos seu descendentes diretos antes de terminar

int main(int argc, char** argv) {

    int son = 0;
    for (int i = 0; i != 2; i++) {
        if(son != 10){
            int a = fork();
            if ( a == 0 ) {
                son = 10;
                printf("Processo %d, filho de %d\n", getpid(), getppid());
            }
        }
    }
    if (son == 10) {
        for (int i = 0; i != 3; i++) {
            fflush(stdout);
            if (fork() == 0 && son!=100) {
                son = 100;
                printf("Processo %d, filho de %d\n", getpid(), getppid());
                sleep(5);
                printf("Processo %d finalizado\n", getpid());
            }
        }
    }

    if(son == 10) {
        printf("Processo %d finalizado\n", getpid()); 
    }
    while(wait(NULL) > 0);
    
    if (son != 100 && son!= 10){
        printf("Processo principal %d finalizado\n", getpid());
    }

    return 0;
}
