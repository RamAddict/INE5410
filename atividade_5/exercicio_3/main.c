#include <stdio.h>
#include <pthread.h>
#include <semaphore.h>
#include <time.h>
#include <stdlib.h>

FILE* out;
sem_t tapir[2];
void *thread_a(void *args) {
    for (int i = 0; i < *(int*)args; ++i) {
        sem_wait(&tapir[0]);
        fprintf(out, "A");
        sem_post(&tapir[1]);
        // Importante para que vocês vejam o progresso do programa
        // mesmo que o programa de vocês trave em um sem_wait().
        fflush(stdout);
    }
    return NULL;
}

void *thread_b(void *args) {
    for (int i = 0; i < *(int*)args; ++i) {
        sem_wait(&tapir[1]);
        fprintf(out, "B");
        sem_post(&tapir[0]);
        fflush(stdout);
    }
    return NULL;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Uso: %s iteracoes\n", argv[0]);
        return 1;
    }
    int iters = atoi(argv[1]);
    srand(time(NULL));
    out = fopen("result.txt", "w");

    pthread_t ta, tb;
    // Inicia semaforos
    sem_init(&tapir[0], 0, 1);
    sem_init(&tapir[1], 0, 1);
    // Cria threads
    pthread_create(&tb, NULL, thread_b, &iters);
    pthread_create(&ta, NULL, thread_a, &iters);

    // Espera pelas threads
    pthread_join(ta, NULL);
    pthread_join(tb, NULL);
    sem_destroy(&tapir[0]);
    sem_destroy(&tapir[1]);

    //Imprime quebra de linha e fecha arquivo
    fprintf(out, "\n");
    fclose(out);
  
    return 0;
}
