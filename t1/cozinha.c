#ifndef cozinha_c
#define cozinha_c
#include <stdio.h>
#include "cozinha.h"
#include <stdlib.h>

sem_t sem_cozinheiros;
sem_t sem_bocas;
sem_t sem_frigideiras;
sem_t sem_garcons;
sem_t sem_balcao;

void cozinha_init(int cozinheiros, int bocas, int frigideiras, int garcons,
                  int tam_balcao) {
    sem_init(&sem_cozinheiros, 0, cozinheiros);
    sem_init(&sem_bocas, 0, bocas);
    sem_init(&sem_frigideiras, 0, frigideiras);
    sem_init(&sem_garcons, 0, garcons);
    sem_init(&sem_balcao, 0, tam_balcao);
    printf("INICIALIZANDO COZINHA\n");
}
void cozinha_destroy() {
    sem_destroy(&sem_cozinheiros);
    sem_destroy(&sem_bocas);
    sem_destroy(&sem_frigideiras);
    sem_destroy(&sem_garcons);
    sem_destroy(&sem_balcao);
}
    void* worker(void* work) {
        struct tarefa* job = (struct tarefa*) work;
        switch(job->type) {
            case 0:;
                esquentar_molho((molho_t*)job->ingrediente1);
                sem_post(&sem_bocas);
                break;
            case 1:;
                ferver_agua((agua_t*)job->ingrediente1);
                sem_post(&sem_bocas);
            break;
            case 2:;
                cozinhar_legumes((legumes_t*)job->ingrediente1, (caldo_t*)job->ingrediente2);
                sem_post(&sem_bocas);
            break;
            case 3:;
                caldo_t* caldo = preparar_caldo((agua_t*)job->ingrediente1);
                sem_post(&sem_bocas);
                return (void*)caldo;
            break;
        }
        return NULL;
    }
//////////////////////////////////CARNE///////////////////////////////////////////////////////////////////
    void* pedido_carne(void * arg) {

        pedido_t pedido = *((pedido_t*) arg);

            //! tentando ocupar um cozinheiro
            sem_wait(&sem_cozinheiros);

            printf("Pedido %d (CARNE) iniciando!\n", pedido.id);
            
            //! Pegando carne
            carne_t* carne1 = create_carne();
            
            //! Cortando carne 5MIN [DE]
            cortar_carne(carne1);
            //! Temperar carne 3MIN [DE]
            temperar_carne(carne1);
            //////////WAIT
            //! Privatizando uma boca
            sem_wait(&sem_bocas);
            //! Privatizando uma frigideira
            sem_wait(&sem_frigideiras);
            
            //! Grelhando carne 3MIN [DE]
            grelhar_carne(carne1);

             //////////POST
            //! Devolvendo uma boca
            sem_post(&sem_bocas);
            //! Devolvendo uma frigideira
            sem_post(&sem_frigideiras);
          
            //! cria prato
            prato_t* plate = create_prato(pedido);

            
            //! emprata a carne
            empratar_carne(carne1, plate);
            //! tentando colocar no balcão
            sem_wait(&sem_balcao);
            
            //! notificando prato no balcão
            notificar_prato_no_balcao(plate);
            //! libera o cozinheiro que era responsável por este prato
            sem_post(&sem_cozinheiros);

            //! tenta chamar garçom
            sem_wait(&sem_garcons);
            //! libera espaço no balcão depois do garçom pegar um prato
            sem_post(&sem_balcao);
            //! entrega pedido
            entregar_pedido(plate);
            //! libera garçom que estava entregando o prato
            sem_post(&sem_garcons);

            free((pedido_t*) arg);
            return NULL;
        }  // end pedido_carnes

//////////////////////////////////SPAGET///////////////////////////////////////////////////////////////////
    void* pedido_spaghetti(void* arg) {
        pedido_t pedido = *((pedido_t*) arg);
        //! tentando ocupar um cozinheiro
        sem_wait(&sem_cozinheiros);

        printf("Pedido %d (SPAGHETTI) iniciando!\n", pedido.id);

        //! criando treads p fazer coisas nao DE
        pthread_t treds[2];

        molho_t* molho = create_molho();
        struct tarefa tarefa_molho;
        tarefa_molho.type = 0;
        tarefa_molho.ingrediente1 = (void*) molho;

        sem_wait(&sem_bocas);
        pthread_create(&treds[0], NULL, worker, (void*)&tarefa_molho);

        agua_t* agua = create_agua();
        struct tarefa tarefa_agua;
        tarefa_agua.type = 1;
        tarefa_agua.ingrediente1 = (void*)agua;
        sem_wait(&sem_bocas);
        pthread_create(&treds[1], NULL, worker, (void*)&tarefa_agua);

        bacon_t* bacon = create_bacon();
        sem_wait(&sem_bocas);
        sem_wait(&sem_frigideiras);
        dourar_bacon(bacon);
        sem_post(&sem_bocas);
        sem_post(&sem_frigideiras);
        pthread_join(treds[1], NULL);

        spaghetti_t* moms = create_spaghetti();
        sem_wait(&sem_bocas);
        cozinhar_spaghetti(moms, agua);
        sem_post(&sem_bocas);
         //! posso empratar sem verificar se terminei de esquentar o molho
         //em funcao do tempo que ele vai
         //levar necessariamente p/ cozinhar o spaget
        prato_t* plate = create_prato(pedido);

        //! empratar spaghetti
        empratar_spaghetti(moms, molho, bacon, plate);
        //! espera ter espaço no balcão
        sem_wait(&sem_balcao);
        //printf("prato pronto %d, cozinheiro liberado\n", pedido.id);
        //! notificando prato no balcão
        notificar_prato_no_balcao(plate);
        //! libera o cozinheiro que era responsável por este prato
        sem_post(&sem_cozinheiros);

        //! tenta chamar garçom
        sem_wait(&sem_garcons);
        //! libera espaço no balcão depois do garçom pegar um prato
        sem_post(&sem_balcao);
        //! entrega pedido
        entregar_pedido(plate);
        //! libera garçom que estava entregando o prato
        sem_post(&sem_garcons);
        free((pedido_t*) arg);
        return NULL;
    }  // end pedido_spaghetti

    void* pedido_sopa(void* arg) {
        pedido_t pedido = *((pedido_t*) arg);

        sem_wait(&sem_cozinheiros);
        printf("Pedido %d (SOPA) iniciando!\n", pedido.id);

        pthread_t treds[1];
        
        agua_t* agua = create_agua();

        struct tarefa job;

        job.type = 1;
        job.ingrediente1 = (void*) agua;

        sem_wait(&sem_bocas);
        pthread_create(&treds[0], NULL, worker, (void*)&job);

        legumes_t* legumes = create_legumes();

        cortar_legumes(legumes);

        sem_wait(&sem_bocas);// consirando que fazer o caldo precisa de uma boca

        caldo_t* caldo =  preparar_caldo(agua);

        sem_post(&sem_bocas);

        sem_wait(&sem_bocas);

        cozinhar_legumes(legumes, caldo);

        sem_post(&sem_bocas);

        prato_t* plate = create_prato(pedido);

        empratar_sopa(legumes, caldo, plate);

        sem_wait(&sem_balcao);

        notificar_prato_no_balcao(plate);

        sem_post(&sem_cozinheiros);

        sem_wait(&sem_garcons);
        
        sem_post(&sem_balcao);

        entregar_pedido(plate);

        sem_post(&sem_garcons);
        free((pedido_t*) arg);
        return NULL;
    }


void processar_pedido(pedido_t p) {
    pedido_t* pedido = (pedido_t*) malloc(sizeof(pedido_t));
    *pedido = p;
    switch(p.prato) {
        case PEDIDO_NULL:
        printf("prato null, larga de zueira");
        break;
        case PEDIDO_SPAGHETTI:;
        printf("Pedido %d (SPAGHETTI) submetido!\n", p.id);
        pthread_t cook_for_spaghetti;
        pthread_create(&cook_for_spaghetti, NULL, pedido_spaghetti, (void*)pedido);
        break;
        case PEDIDO_SOPA:;
        printf("Pedido %d (SOPA) submetido!\n", p.id);
        pthread_t cook_for_soup;
        pthread_create(&cook_for_soup, NULL, pedido_sopa, (void*)pedido);
        break;
        case PEDIDO_CARNE:;
        printf("Pedido %d (CARNE) submetido!\n", p.id);
        pthread_t cook_for_meat;
        pthread_create(&cook_for_meat, NULL, pedido_carne, (void*)pedido);

        break;
        case PEDIDO__SIZE:

        break;

    }
}


#endif