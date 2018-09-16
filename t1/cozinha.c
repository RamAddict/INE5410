#ifndef cozinha_c
#define cozinha_c
#include <stdio.h>
#include "cozinha.h"
#include <stdlib.h>


void cozinha_init(int cozinheiros, int bocas, int frigideiras, int garcons,
                  int tam_balcao, struct semaphores* sems) {

    printf("inicializando semaphores: BEFORE malloc\n");
    (*sems).sem_cozinheiros = (sem_t*) malloc(sizeof(sem_t));
    (*sems).sem_bocas = (sem_t*) malloc(sizeof(sem_t));
    (*sems).sem_frigideiras = (sem_t*) malloc(sizeof(sem_t));
    (*sems).sem_garcons = (sem_t*) malloc(sizeof(sem_t));
    (*sems).sem_balcao = (sem_t*) malloc(sizeof(sem_t));
    printf("inicializando semaphores: BEFORE sem_init\n");
    sem_init((*sems).sem_cozinheiros, 0, cozinheiros);
    sem_init((*sems).sem_bocas, 0, bocas);
    sem_init((*sems).sem_frigideiras, 0, frigideiras);
    sem_init((*sems).sem_garcons, 0, garcons);
    sem_init((*sems).sem_balcao, 0, tam_balcao);
    printf("inicializando semaphores: AFTER sem_init\n");

}
void cozinha_destroy(struct semaphores* sems) {
    free(sems->sem_cozinheiros);
    free(sems->sem_bocas);
    free(sems->sem_frigideiras);
    free(sems->sem_garcons);
    free(sems->sem_balcao);
    sem_destroy((sems)->sem_cozinheiros);
    sem_destroy((sems)->sem_bocas);
    sem_destroy((sems)->sem_frigideiras);
    sem_destroy((sems)->sem_garcons);
    sem_destroy((sems)->sem_balcao);
}
void processar_pedido(pedido_t p, struct semaphores* sems) {
    void* worker(void* work) {
        struct tarefa* job = (struct tarefa*) work;
        switch(job->type) {
            case 0:;
                esquentar_molho((molho_t*)job->ingrediente1);
                sem_post(sems->sem_bocas);
                break;
            case 1:;
                ferver_agua((agua_t*)job->ingrediente1);
                sem_post(sems->sem_bocas);
            break;
            case 2:;
                cozinhar_legumes((legumes_t*)job->ingrediente1, (caldo_t*)job->ingrediente2);
                sem_post(sems->sem_bocas);
            break;
            case 3:;
                caldo_t* caldo = preparar_caldo((agua_t*)job->ingrediente1);
                sem_post(sems->sem_bocas);
                return (void*)caldo;
            break;
        }
        return NULL;
    }

//////////////////////////////////CARNE///////////////////////////////////////////////////////////////////    
    void* pedido_carnes(void * arg) {
        printf("N chega aq \n");
            //! tentando ocupar um cozinheiro
            sem_wait(sems->sem_cozinheiros);           
            
            printf("Cozinheiro iniciou pedido: Carne %d\n", p.id);
        
        
            //! Pegando carne
            carne_t* carne1 = create_carne();
            //! Cortando carne 5MIN [DE]
            cortar_carne(carne1);  
            //! Temperar carne 3MIN [DE]
            temperar_carne(carne1);  
            
            //////////WAIT
            //! Privatizando uma boca
            sem_wait(sems->sem_bocas);  
            //! Privatizando uma frigideira
            sem_wait(sems->sem_frigideiras);  
            
            //! Grelhando carne 3MIN [DE]
            grelhar_carne(carne1);  
            
             //////////POST
            //! Devolvendo uma boca
            sem_post(sems->sem_bocas);  
            //! Devolvendo uma frigideira
            sem_post(sems->sem_frigideiras);  


            //! cria prato
            prato_t* plate = create_prato(p);
            
            
            //! emprata a carne 
            empratar_carne(carne1, plate);
            //! tentando colocar no balcão
            sem_wait(sems->sem_balcao);
            printf("prato pronto %d, cozinheiro liberado\n", p.id);
            //! notificando prato no balcão
            notificar_prato_no_balcao(plate);
            //! libera o cozinheiro que era responsável por este prato
            sem_post(sems->sem_cozinheiros);
            
            //! tenta chamar garçom
            sem_wait(sems->sem_garcons);
            //! libera espaço no balcão depois do garçom pegar um prato
            sem_post(sems->sem_balcao);
            //! entrega pedido 
            entregar_pedido(plate);
            //! libera garçom que estava entregando o prato
            sem_post(sems->sem_garcons);

            return NULL;
        }  // end pedido_carnes

//////////////////////////////////SPAGET///////////////////////////////////////////////////////////////////
    void* pedido_spaghetti(void* arg) {
        //! tentando ocupar um cozinheiro
        sem_wait(sems->sem_cozinheiros);
        
        printf("Cozinheiro iniciou pedido: spaghetti %d\n", p.id);
        
        //! criando treads p fazer coisas nao DE        
        pthread_t treds[2];
        
        molho_t* molho = create_molho();
        struct tarefa tarefa_molho;
        tarefa_molho.type = 0;
        tarefa_molho.ingrediente1 = (void*) molho;
        
        sem_wait(sems->sem_bocas);
        pthread_create(&treds[0], NULL, worker, (void*)&tarefa_molho);

        agua_t* agua = create_agua();
        struct tarefa tarefa_agua;
        tarefa_agua.type = 1;
        tarefa_agua.ingrediente1 = (void*)agua;
        sem_wait(sems->sem_bocas);
        pthread_create(&treds[1], NULL, worker, (void*)&tarefa_agua);
        
        bacon_t* bacon = create_bacon();
        sem_wait(sems->sem_bocas);
        sem_wait(sems->sem_frigideiras);
        dourar_bacon(bacon);
        sem_post(sems->sem_bocas);
        sem_post(sems->sem_frigideiras);
        pthread_join(treds[1], NULL);

        spaghetti_t* moms = create_spaghetti();
        sem_wait(sems->sem_bocas);
        cozinhar_spaghetti(moms, agua);
        sem_post(sems->sem_bocas);
         //! posso empratar sem verificar se terminei de esquentar o molho
         //em funcao do tempo que ele vai 
         //levar necessariamente p/ cozinhar o spaget
        prato_t* plate = create_prato(p);

        //! empratar spaghetti
        empratar_spaghetti(moms, molho, bacon, plate);
        //! espera ter espaço no balcão
        sem_wait(sems->sem_balcao);
        printf("prato pronto %d, cozinheiro liberado\n", p.id);
        //! notificando prato no balcão
        notificar_prato_no_balcao(plate);
        //! libera o cozinheiro que era responsável por este prato
        sem_post(sems->sem_cozinheiros);
        
        //! tenta chamar garçom
        sem_wait(sems->sem_garcons);
        //! libera espaço no balcão depois do garçom pegar um prato
        sem_post(sems->sem_balcao);
        //! entrega pedido 
        entregar_pedido(plate);
        //! libera garçom que estava entregando o prato
        sem_post(sems->sem_garcons);

        return NULL;
    }  // end pedido_spaghetti
 
    
    
    
    
    switch(p.prato) {
        case PEDIDO_NULL:
        printf("prato null, larga de zueira");
        break;
        case PEDIDO_SPAGHETTI:;

        // pthread_t cook_for_spaghetti;
        // printf("Do i get here?\n");
        // pthread_create(&cook_for_spaghetti, NULL, pedido_spaghetti, NULL);
        break;
        case PEDIDO_SOPA:

        break;
        case PEDIDO_CARNE:;
        pthread_t cook_for_meat;
        pthread_create(&cook_for_meat, NULL, pedido_carnes, (void*)NULL);
        
        break;
        case PEDIDO__SIZE:

        break;

    }
}
// void* preparar_carne(void* args) {
//     struct semaphores sem = *((struct semaphores*) args);
    
//     sem_t sem_bocas = *sem.sem_bocas;
//     sem_t sem_frigideiras = *sem.sem_frigideiras;

//     //! Pegando carne
//     carne_t* carne1 = create_carne();  
//     //! Cortando carne 5MIN [DE]
//     cortar_carne(carne1);  
//     //! Temperar carne 3MIN [DE]
//     temperar_carne(carne1);  
//     //////////WAIT
//     sem_wait(&sem_bocas);  //! Privatizando uma boca
//     sem_wait(&sem_frigideiras);  //! Privatizando uma frigideira
    
//     grelhar_carne(carne1);  //! Grelhando carne 3MIN [DE]
    
//     sem_post(&sem_bocas);  //! Devolvendo uma boca
//     sem_post(&sem_frigideiras);  //! Devolvendo uma frigideira
//     //////////POST
//     //prato_t* plate = create_prato(pedido);
//     //empratar_carne(carne1, plate);  //! Empretar a carne 1MIN [DE]
//     return (void*) carne1;
// }
// void* preparar_sopa() {

// }



#endif