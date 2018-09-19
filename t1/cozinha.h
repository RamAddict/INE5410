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
extern void  processar_pedido(pedido_t p);
extern void* preparar_carne(void* arg);
extern void* preparar_sopa(void* arg);
extern void* pedido_spaghetti(void* arg);
void* pedido_spaghetti(void* arg);
void* pedido_carne(void * arg);
void* worker(void* work);

#endif /*__COZINHA_H__*/
