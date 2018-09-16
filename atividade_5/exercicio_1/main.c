#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <stdio.h>
#include <pthread.h>
#include <time.h>
#include <semaphore.h>

int produzir(int value);    //< definida em helper.c
void consumir(int produto); //< definida em helper.c
void *ProdutorFunc(void *arg);
void *ConsumidorFunc(void *arg);

int indice_produtor, indice_consumidor, tamanho_buffer;
int* buffer;

sem_t semaforo_produtor;
sem_t semaforo_consumidor;
//Você deve fazer as alterações necessárias nesta função e na função
//ConsumidorFunc para que usem semaforo_consumidoráforos para coordenar a produção
//e consumo de elementos do buffer.
void *ProdutorFunc(void *arg) {
    //arg contem o número de itens a serem produzidos
    int max = *((int*)arg);
    for (int i = 0; i <= max; ++i) {
        int produto;
        if (i == max) {
          produto = -1;          //envia produto sinlizando FIM
        }
        else {
            //printf("Thread pegou pra produzir %d ", indice_consumidor);
            produto = produzir(i); //produz um elemento normal
          }
        indice_produtor = (indice_produtor + 1) % tamanho_buffer; //calcula posição próximo elemento
        sem_wait(&semaforo_produtor);
        buffer[indice_produtor] = produto; //adiciona o elemento produzido à lista
        sem_post(&semaforo_consumidor);
    }
    return NULL;
}

void *ConsumidorFunc(void *arg) {
    while (1) {
        indice_consumidor = (indice_consumidor + 1) % tamanho_buffer; //Calcula o próximo item a consumir
        sem_wait(&semaforo_consumidor);
        int produto = buffer[indice_consumidor]; //obtém o item da lista
        sem_post(&semaforo_produtor);
        //Podemos receber um produto normal ou um produto especial
        if (produto >= 0) {
          consumir(produto); //Consome o item obtido.
        } else
            break; //produto < 0 é um sinal de que o consumidor deve parar
    }
    return NULL;
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        printf("Uso: %s tamanho_buffer itens_produzidos\n", argv[0]);
        return 0;
    }

    tamanho_buffer = atoi(argv[1]);
    int n_itens = atoi(argv[2]);

    //Iniciando buffer
    indice_produtor = 0;
    indice_consumidor = 0;
    buffer = malloc(sizeof(int) * tamanho_buffer);
    sem_init(&semaforo_consumidor, 0, 0);
    sem_init(&semaforo_produtor, 0, tamanho_buffer);
    pthread_t treds[2];
    pthread_create(&treds[1], NULL, ProdutorFunc, (void*)&n_itens);
    pthread_create(&treds[0], NULL, ConsumidorFunc, (void*)&n_itens);
    // Crie threads e o que mais for necessário para que uma produtor crie
    // n_itens produtos e o consumidor os consuma
    for (int i = 0; i != 2; i++)
      pthread_join(treds[i] ,NULL);
    // ....

    //Libera memória do buffer
    free(buffer);














    sem_destroy(&semaforo_produtor);
    sem_destroy(&semaforo_consumidor);
    return 0;
}
