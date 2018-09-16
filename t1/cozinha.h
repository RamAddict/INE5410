#ifndef __COZINHA_H__
#define __COZINHA_H__

#include "pedido.h"
#include "tarefas.h"
#include <pthread.h>
#include <semaphore.h>

struct semaphores {
sem_t* sem_cozinheiros;
sem_t* sem_bocas;
sem_t* sem_frigideiras;
sem_t* sem_garcons;
sem_t* sem_balcao;
};
struct tarefa {
//molho = 0, agua = 1, legumes = 2, caldo = 3
    unsigned type;
    void* ingrediente1;
    void* ingrediente2;
};

extern void  cozinha_init(int cozinheiros, int bocas, int frigideiras, int garcons, int tam_balcao, struct semaphores* sems);
extern void  cozinha_destroy(struct semaphores* sems);
extern void  processar_pedido(pedido_t p, struct semaphores* sems);
extern void* preparar_carne(void* args);
extern void* preparar_sopa();


#endif /*__COZINHA_H__*/
