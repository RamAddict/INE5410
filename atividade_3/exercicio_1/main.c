#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <stdio.h>
#include <pthread.h>

//                 (main)      
//                    |
//    +----------+----+------------+
//    |          |                 |   
// worker_1   worker_2   ....   worker_n


// ~~~ argumentos (argc, argv) ~~~
// ./program n_threads

// ~~~ printfs  ~~~
// pai (ao criar filho): "Contador: %d\n"
// pai (ao criar filho): "Esperado: %d\n"

// Obs:
// - pai deve criar n_threds (argv[1]) worker threads 
// - cada thread deve incrementar contador_global n_threads*1000
// - pai deve esperar pelas worker threads  antes de imprimir!

void* increment();
int contador_global = 0;
int main(int argc, char* argv[]) {

   if (argc < 2) {
        printf("n_threads é obrigatório!\n");
        printf("Uso: %s n_threads\n", argv[0]);
        return 1;
    }
    int thread_number = atoi(argv[1]);
    pthread_t thrds[thread_number];
    void* retorno;

    for (int i = 0; i < thread_number; i++) {
        pthread_create(&thrds[i], NULL, increment, (void*)&thread_number);
        pthread_join(thrds[i], &retorno);
    }   

 
    //int id = 0;
    
    printf("Contador: %d\n", contador_global);
    printf("Esperado: %d\n", thread_number*1000*thread_number);
    return 0;
}
    void* increment(void* arg) {
        int nThreads = *((int*) arg);
        for (int i = 0; i < 1000*nThreads; i++) {
            contador_global++;
        }
        return NULL;
    }