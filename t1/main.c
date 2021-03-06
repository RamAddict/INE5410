#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <errno.h>
#include <string.h>
#include <pthread.h>
#include <semaphore.h>
#include "cozinha.h"


extern sem_t sem_cozinheiros;
extern sem_t sem_bocas;
extern sem_t sem_frigideiras;
extern sem_t sem_garcons;
extern sem_t sem_balcao;

static struct option cmd_opts[] = {
    {"cozinheiros", required_argument, 0, 'c'},
    {"bocas",       required_argument, 0, 'b'},
    {"fogoes",      required_argument, 0, 'f'},
    {"frigideiras", required_argument, 0, 'r'},
    {"garcons",     required_argument, 0, 'g'},
    {"balcao",      required_argument, 0, 'a'},
    {"help",        no_argument,       0, 'h'},
    {0, 0, 0, 0}
};

int parse_gt_zero(const char* buf, const char* name, int* res) {
    errno = 0;
    *res = strtol(buf, NULL, 10);
    if (errno) {
        fprintf(stderr, "Impossível parsear argumento da opção %s, \"%s\" como "
                "um inteiro: %s\n", name, buf, strerror(errno));
        return 0;
    }
    if (*res <= 0) {
        fprintf(stderr, "Esperava um valor maior que zero para %s, leu: %d\n",
                name, *res);
        return 0;
    }
    return 1;
}
void check_missing(int value, const char* name) {
    if (value > 0) return;
    fprintf(stderr, "%s faltando!\n", name);
    abort();
}

int main(int argc, char** argv) {
    int bocas_total = 0, bocas = 7, frigideiras = 4, fogoes = 2,
        cozinheiros = 6, garcons = 4, balcao = 9, c = 0;
    while (c >= 0) {
        int long_idx;
        c = getopt_long(argc, argv, "cbfrga", cmd_opts, &long_idx);
        if (c == 0) c = cmd_opts[long_idx].val;

        switch (c) {
        case 'c':
            if (!parse_gt_zero(optarg, argv[optind-1], &cozinheiros)) abort();
            break;
        case 'b':
            if (!parse_gt_zero(optarg, argv[optind-1], &bocas      )) abort();
            break;
        case 'f':
            if (!parse_gt_zero(optarg, argv[optind-1], &fogoes     )) abort();
            break;
        case 'r':
            if (!parse_gt_zero(optarg, argv[optind-1], &frigideiras)) abort();
            break;
        case 'g':
            if (!parse_gt_zero(optarg, argv[optind-1], &garcons    )) abort();
            break;
        case 'a':
            if (!parse_gt_zero(optarg, argv[optind-1], &balcao     )) abort();
            break;
        case -1:
            break;
        default:
            abort();
        }
    }

    bocas_total = bocas*fogoes;
    check_missing(cozinheiros, "cozinheiros");
    check_missing(bocas, "bocas");
    check_missing(fogoes, "fogoes");
    check_missing(frigideiras, "frigideiras");
    check_missing(garcons, "garcons");
    check_missing(balcao, "balcao");
    //! struct with the semaphores
    //! inicia semáforos
    cozinha_init(cozinheiros, bocas_total, frigideiras,
                 garcons, balcao);

    char* buf = (char*)malloc(4096);
    int ret = 0;
    int pedidos = 0;

    //!Inicializando variavel de tamanho do array de pedidos com 10
    int size_pedido_array = 10;

    pthread_t* pedido_array = (pthread_t*) malloc(sizeof(pthread_t)*size_pedido_array);

    while((ret = scanf("%4095s", buf)) > 0) {
        //! Alocando espaço de memória para o pedido
        pedido_t* p = malloc(sizeof(pedido_t));
        p->prato = pedido_prato_from_name(buf);

        if (!p->prato) {
            fprintf(stderr, "Pedido inválido descartado: \"%s\"\n", buf);
            //! Se o prato for inválido, o pedido é descartado e o espaço de memória já é liberado
            free(p);
        }
        else {
            //! Define o ID do pedido como pedidos +1, para que o primeiro seja 1
            p->id = pedidos +1;
            //! Caso o número de pedidos seja igual a capacidade máxima do pedido_array

            if(pedidos == size_pedido_array) {
                //! O tamanho do array é dobrado
                size_pedido_array*=2;
                //! E o array de pedidos é realocado para uma memória 2 vezes maior
                pthread_t* pedido_array_new = (pthread_t*) realloc(pedido_array, sizeof(pthread_t[size_pedido_array]));
                if (pedido_array_new == NULL ) {
                    printf("Failed");
                } else {
                    pedido_array = pedido_array_new;
                }
            }
            //! Cria a thread correspondente ao pedido, passando a ela o pedido feito.
            pthread_create(&pedido_array[pedidos], NULL, processar_pedido, (void*)p);
            //! Incrementa a variável pedidos
            pedidos++;
        }
    }
    if (ret != EOF) {
        perror("Erro lendo pedidos de stdin:");
    }
///////////////////////////////////////////////////////////////////////////////////////////////
    for(int i = 0;i < pedidos;i++){
      //! Espera que todos os pedidos sejam entregues
      pthread_join(pedido_array[i], NULL);
    }

    //! Após o fim de todos os pedidos, libera todos os espaços até então alocados.
    free(buf);
    free(pedido_array);
    cozinha_destroy();
    return 0;
}
