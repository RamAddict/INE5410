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
pthread_mutex_t meuOvo = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t meuPau = PTHREAD_MUTEX_INITIALIZER;
sem_t semaforo_produtor;
sem_t semaforo_consumidor;
//Você deve fazer as alterações necessárias nesta função e na função
//ConsumidorFunc para que usem semáforos para coordenar a produção
//e consumo de elementos do buffer.
void* ProdutorFunc(void *arg) {
    //arg contem o número de itens a serem produzidos
    int max = *((int*)arg);
    for (int i = 0; i < max; ++i) {
        int produto;
        // if (i == max)
        //     produto = -1;          //envia produto sinlizando FIM
        // else 
        produto = produzir(i); //produz um elemento normal

        sem_wait(&semaforo_produtor);
        pthread_mutex_lock(&meuOvo);
        indice_produtor = (indice_produtor + 1) % tamanho_buffer; //calcula posição próximo elemento
        buffer[indice_produtor] = produto; //adiciona o elemento produzido à lista
        pthread_mutex_unlock(&meuOvo);
        sem_post(&semaforo_consumidor);
    }
    return NULL;
}

void *ConsumidorFunc(void *arg) {
    while (1) {
        sem_wait(&semaforo_consumidor);
        pthread_mutex_lock(&meuPau);
        indice_consumidor = (indice_consumidor + 1) % tamanho_buffer; //Calcula o próximo item a consumir
        int produto = buffer[indice_consumidor]; //obtém o item da lista
        pthread_mutex_unlock(&meuPau);
        sem_post(&semaforo_produtor);
        //Podemos receber um produto normal ou um produto especial
        if (produto >= 0)
            consumir(produto); //Consome o item obtido.
        else
            break; //produto < 0 é um sinal de que o consumidor deve parar
    }
    return NULL;
}

int main(int argc, char *argv[]) {
    if (argc < 5) {
        printf("Uso: %s tamanho_buffer itens_produzidos n_produtores n_consumidores \n", argv[0]);
        return 0;
    }

    tamanho_buffer = atoi(argv[1]);
    int itens = atoi(argv[2]);
    int n_produtores = atoi(argv[3]);
    int n_consumidores = atoi(argv[4]);

    //Iniciando buffer
    indice_produtor = 0;
    indice_consumidor = 0;
    buffer = malloc(sizeof(int) * tamanho_buffer);

    sem_init(&semaforo_consumidor, 0, 0);
    sem_init(&semaforo_produtor, 0, tamanho_buffer);

    pthread_t treds_prod[n_produtores];
    pthread_t treds_cons[n_consumidores];
    //PRODUTORES
    for (int i = 0; i != n_produtores; i++) 
        pthread_create(&treds_prod[i], NULL, ProdutorFunc, (void*)&itens);
    //CONSUMIDORES
    for (int i = 0; i != n_consumidores; i++)
        pthread_create(&treds_cons[i], NULL, ConsumidorFunc, NULL);
    // Crie threads e o que mais for necessário para que uma produtor crie
    // n_itens produtos e o consumidor os consuma
    for (int i = 0; i != n_produtores; i++)
        pthread_join(treds_prod[i] ,NULL);

        for (int i = 0; i != n_consumidores; i++) {
            sem_wait(&semaforo_produtor);
            buffer[indice_produtor = (indice_produtor+1) % tamanho_buffer] = -1;
            sem_post(&semaforo_consumidor);
        }



    for (int i = 0; i != n_consumidores; i++)    
        pthread_join(treds_cons[i] ,NULL);
        
    // ....
    
    //Libera memória do buffer
    free(buffer);

    sem_destroy(&semaforo_produtor);
    sem_destroy(&semaforo_consumidor);

    pthread_mutex_destroy(&meuOvo);
    pthread_mutex_destroy(&meuPau);
    return 0;
} //fuk n sei nem errar essa questão ;(

