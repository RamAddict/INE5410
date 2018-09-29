#ifndef __COZINHA_H__
#define __COZINHA_H__

#include "pedido.h"
#include "tarefas.h"
#include <pthread.h>
#include <semaphore.h>

struct tarefa {
//molho = 0, agua = 1, legumes = 2, caldo = 3
    unsigned type;
    void* ingrediente1;
    void* ingrediente2;
};

extern void  cozinha_init(int cozinheiros, int bocas, int frigideiras, int garcons, int tam_balcao);
extern void  cozinha_destroy();
extern void*  processar_pedido(void* p);
void pedido_spaghetti(pedido_t* pedido);
void pedido_carne(pedido_t* pedido);
void pedido_sopa(pedido_t* pedido);
void* worker(void* work);

#endif /*__COZINHA_H__*/
