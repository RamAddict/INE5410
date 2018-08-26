#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <stdio.h>
#include <string.h>
//       (pai)
//         |
//    +----+----+
//    |         |
// filho_1   filho_2


// ~~~ printfs  ~~~
// pai (ao criar filho): "Processo pai criou %d\n"
//    pai (ao terminar): "Processo pai finalizado!\n"
//  filhos (ao iniciar): "Processo filho %d criado\n"

// Obs:
// - pai deve esperar pelos filhos antes de terminar!


int main(int argc, char** argv) {

    int son = 0;
    for (int i = 0; i != 2; i++) {
        if(son != 10){
            int a = fork();
            if(a > 0) {
                printf("Processo pai criou %d\n",a);
            }
            if ( a == 0 ) {
                son = 10;
                printf("Processo filho %d criado\n", getpid());
            }
        }
    }

    while(wait(NULL) > 0);
    if(son != 10) {
        printf("Processo pai finalizado!\n");
    }
    return 0;
}
