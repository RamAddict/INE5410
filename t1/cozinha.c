#ifndef cozinha_c
#define cozinha_c
#include <stdio.h>
#include "cozinha.h"



void cozinha_init(int cozinheiros, int bocas, int frigideiras, int garcons, int tam_balcao, struct semaphores* sems) {

    sem_init((sems)->sem_cozinheiros, 0, cozinheiros);
    sem_init((sems)->sem_bocas, 0, bocas);
    sem_init((sems)->sem_frigideiras, 0, frigideiras);
    sem_init((sems)->sem_garcons, 0, garcons);
    sem_init((sems)->sem_balcao, 0, tam_balcao);

}
void cozinha_destroy(struct semaphores* sems) {
    sem_destroy((sems)->sem_cozinheiros);
    sem_destroy((sems)->sem_bocas);
    sem_destroy((sems)->sem_frigideiras);
    sem_destroy((sems)->sem_garcons);
    sem_destroy((sems)->sem_balcao);
}
void processar_pedido(pedido_t p, struct semaphores* sems) {
    void* pedido_carnes(void * arg) {
  
            //! tentando ocupar um cozinheiro
            sem_wait(sems->sem_cozinheiros);           
        
        
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
        }
    switch(p.prato) {
        case PEDIDO_NULL:
        printf("prato null, larga de zueira");
        break;
        case PEDIDO_SPAGHETTI:

        break;
        case PEDIDO_SOPA:

        break;
        case PEDIDO_CARNE:;
        
        pthread_t cook;
        pthread_create(&cook,NULL, pedido_carnes, (void *)NULL);


       
        break;
        case PEDIDO__SIZE:

        break;

    }
}
void* preparar_carne(void* args) {
    struct semaphores sem = *((struct semaphores*) args);
    
    sem_t sem_bocas = *sem.sem_bocas;
    sem_t sem_frigideiras = *sem.sem_frigideiras;

    //! Pegando carne
    carne_t* carne1 = create_carne();  
    //! Cortando carne 5MIN [DE]
    cortar_carne(carne1);  
    //! Temperar carne 3MIN [DE]
    temperar_carne(carne1);  
    //////////WAIT
    sem_wait(&sem_bocas);  //! Privatizando uma boca
    sem_wait(&sem_frigideiras);  //! Privatizando uma frigideira
    
    grelhar_carne(carne1);  //! Grelhando carne 3MIN [DE]
    
    sem_post(&sem_bocas);  //! Devolvendo uma boca
    sem_post(&sem_frigideiras);  //! Devolvendo uma frigideira
    //////////POST
    //prato_t* plate = create_prato(pedido);
    //empratar_carne(carne1, plate);  //! Empretar a carne 1MIN [DE]
    return (void*) carne1;
}
// void* preparar_sopa() {

// }



#endif