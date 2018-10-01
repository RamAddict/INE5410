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
  //! inicializa semáforos com o numero respectivo de bocas, frigideiras, garçons, cozinheiros e o tam_balcao
void cozinha_init(int cozinheiros, int bocas, int frigideiras, int garcons,
                  int tam_balcao) {
    sem_init(&sem_cozinheiros, 0, cozinheiros);
    sem_init(&sem_bocas, 0, bocas);
    sem_init(&sem_frigideiras, 0, frigideiras);
    sem_init(&sem_garcons, 0, garcons);
    sem_init(&sem_balcao, 0, tam_balcao);
    printf("INICIALIZANDO COZINHA\n");
}
  //! destroi semáforos
void cozinha_destroy() {
    sem_destroy(&sem_cozinheiros);
    sem_destroy(&sem_bocas);
    sem_destroy(&sem_frigideiras);
    sem_destroy(&sem_garcons);
    sem_destroy(&sem_balcao);
}

  //! Função que executará as tarefas não DE
void* worker(void* work) {
/**
  Função que executará as tarefas não DE. É criada uma thread que executa worker,
  e recebe struct tarefa com o tipo do trabalho a ser feito e
  ingredientes que precisará para executar a tarefa.
*/
        struct tarefa* job = (struct tarefa*) work;
        switch(job->type) {
            case 0:;
                esquentar_molho((molho_t*)job->ingrediente1);
                //! Liberando boca usada
                sem_post(&sem_bocas);
                break;
            case 1:;
                ferver_agua((agua_t*)job->ingrediente1);
                //! Liberando boca usada
                sem_post(&sem_bocas);
            break;
            case 2:;
                cozinhar_legumes((legumes_t*)job->ingrediente1, (caldo_t*)job->ingrediente2);
                //! Liberando boca usada
                sem_post(&sem_bocas);
            break;
            case 3:;
                caldo_t* caldo = preparar_caldo((agua_t*)job->ingrediente1);
                //! Liberando boca usada
                sem_post(&sem_bocas);
                return (void*)caldo;
            break;
        }
        return NULL;
    }
//////////////////////////////////CARNE///////////////////////////////////////////////////////////////////
void pedido_carne(pedido_t* pedido) {

        //! tentando ocupar um cozinheiro
        sem_wait(&sem_cozinheiros);

        printf("Pedido %d (CARNE) iniciando!\n", pedido->id);

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
        prato_t* plate = create_prato(*pedido);


        //! emprata a carne
        empratar_carne(carne1, plate);
        //! tentando colocar no balcão
        sem_wait(&sem_balcao);

        //! como quem notifica prato no balcao é o cozinheiro,
        //! entao optamos por notificar_prato antes de liberar o cozinheiro
        //! pense no cozinheiro batendo um sino, p avisar o garçom
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

        free(pedido);
    }  // end pedido_carnes

//////////////////////////////////SPAGET///////////////////////////////////////////////////////////////////
void pedido_spaghetti(pedido_t* pedido) {

    //! tentando ocupar um cozinheiro
    sem_wait(&sem_cozinheiros);

    printf("Pedido %d (SPAGHETTI) iniciando!\n", pedido->id);

    //! criando treads p fazer coisas nao DE
    pthread_t treds[2];

    //! Criando molho a ser usado e criando estrutura a ser passada a thread worker
    molho_t* molho = create_molho();
    struct tarefa tarefa_molho;
    tarefa_molho.type = 0;
    tarefa_molho.ingrediente1 = (void*) molho;

    //! Cozinhero espera uma boca livre para deixar molho esquentando
    sem_wait(&sem_bocas);
    //! Coloca molho para esquetar
    pthread_create(&treds[0], NULL, worker, (void*)&tarefa_molho);

    //! Criando agua a ser usada e criando estrutura a ser passada a thread worker
    agua_t* agua = create_agua();
    struct tarefa tarefa_agua;
    tarefa_agua.type = 1;
    tarefa_agua.ingrediente1 = (void*)agua;

    //! Cozinhero espera uma boca livre para deixar agua fervendo
    sem_wait(&sem_bocas);
    //! Coloca agua pra ferver
    pthread_create(&treds[1], NULL, worker, (void*)&tarefa_agua);

    //! Cria bacon a ser usado
    bacon_t* bacon = create_bacon();

    //! Espera por uma boca livre
    sem_wait(&sem_bocas);
    //! Espera por uma frigideira livre
    sem_wait(&sem_frigideiras);
    //! Doura o bacon
    dourar_bacon(bacon);
    //! Libera boca usada
    sem_post(&sem_bocas);
    //! Libera frigideira usada
    sem_post(&sem_frigideiras);

    //! Cria spaghetti
    spaghetti_t* moms = create_spaghetti();
    //! Espera que agua esteja fervida, pois será usada para cozer o spaghetti
    pthread_join(treds[1], NULL);
    //! Espera por uma boca livre
    sem_wait(&sem_bocas);
    //! Cozinha spaghetti na agua fervida
    cozinhar_spaghetti(moms, agua);
    //! Libera boca usada
    sem_post(&sem_bocas);
    //! Cria um prato de spaghetti
    prato_t* plate = create_prato(*pedido);
    //! Espera até que o molho esteja pronto
    pthread_join(treds[0], NULL);
    //! Emprata spaghetti com o spaghetti cozido, o molho esquentado e o bacon frito
    empratar_spaghetti(moms, molho, bacon, plate);
    //! Joga agua fora, pois não foi usada no prato, somente no cozer do spaghetti
    destroy_agua(agua);
    //! Espera por espaço no balcão
    sem_wait(&sem_balcao);

    //! como quem notifica prato no balcao é o cozinheiro,
    //! entao optamos por notificar_prato antes de liberar o cozinheiro
    //! pense no cozinheiro batendo um sino, p avisar o garçom
    notificar_prato_no_balcao(plate);
    //! libera o cozinheiro que era responsável por este prato
    sem_post(&sem_cozinheiros);

    //! Prato permanece no balcão até que haja um garçom livre
    sem_wait(&sem_garcons);
    //! Libera espaço no balcão depois do garçom pegar um prato
    sem_post(&sem_balcao);
    //! Entrega pedido
    entregar_pedido(plate);
    //! Libera garçom que estava entregando o prato
    sem_post(&sem_garcons);
    //! Libera espaço de memória do pedido
    free(pedido);

}  // end pedido_spaghetti

void pedido_sopa(pedido_t* pedido) {
    //! Espera que um cozinheiro esteja livre
    sem_wait(&sem_cozinheiros);
    printf("Pedido %d (SOPA) iniciando!\n", pedido->id);
    //! Thread necessária para atividade não DE
    pthread_t treds[1];
    //! Cria a agua a ser usada
    agua_t* agua = create_agua();

    //! Cria estrutura a ser passada a thread worker
    struct tarefa job;
    //! ferver_agua
    job.type = 1;
    job.ingrediente1 = (void*) agua;

    //! Espera por uma boca livre
    sem_wait(&sem_bocas);
    //! Deixa a agua fervendo
    pthread_create(&treds[0], NULL, worker, (void*)&job);

    //! Pega/Cria legumes a serem usados
    legumes_t* legumes = create_legumes();
    //! Corta legumes
    cortar_legumes(legumes);
    //! Espera até que agua termine de ferver
    pthread_join(treds[0], NULL);
    //! Espera por uma boca livre
    sem_wait(&sem_bocas);// consirando que fazer o caldo precisa de uma boca
    //! Prepara um caldo com a agua fervida
    caldo_t* caldo =  preparar_caldo(agua);
    //! Usa a mesma boca para cozinhar legumes após preparar caldo
    cozinhar_legumes(legumes, caldo);
    //! Libera boca usada
    sem_post(&sem_bocas);
    //! Cria/Pega um prato de sopa
    prato_t* plate = create_prato(*pedido);
    //! Emprata a sopa com o caldo e os legumes
    empratar_sopa(legumes, caldo, plate);
    //! Espera por um espaço no balcão para deixar o prato
    sem_wait(&sem_balcao);

    //! como quem notifica prato no balcao é o cozinheiro,
    //! entao optamos por notificar_prato antes de liberar o cozinheiro
    //! pense no cozinheiro batendo um sino, p avisar o garçom
    notificar_prato_no_balcao(plate);
    //! Após deixar prato no balcão e notificá-lo libera o cozinheiro
    sem_post(&sem_cozinheiros);
    //! Espera por um garçom livre para entregar o prato
    sem_wait(&sem_garcons);
    //! Libera espaço no balcão quando garçom pega o prato
    sem_post(&sem_balcao);
    //! Entrega o pedido
    entregar_pedido(plate);
    //! Libera o garçom
    sem_post(&sem_garcons);
    //! Libera espaço na memório do pedido
    free(pedido);

}

 //! recebe o pedido da main, aqui ele decide o que vai fazer.
 //! quem chegou aqui executa o pedido, e dentro do pedido é feito o wait
 //! no semaforo dos cozinheiros.
void* processar_pedido(void *arg) {
    pedido_t* pedido = (pedido_t*)arg;
    switch(pedido->prato) {
        case PEDIDO_NULL:
        printf("prato null");
        free(pedido);
        break;


        case PEDIDO_SPAGHETTI:
        printf("Pedido %d (SPAGHETTI) submetido!\n", pedido->id);
        pedido_spaghetti(pedido);
        break;

        case PEDIDO_SOPA:
        printf("Pedido %d (SOPA) submetido!\n", pedido->id);
        pedido_sopa(pedido);
        break;

        case PEDIDO_CARNE:
        printf("Pedido %d (CARNE) submetido!\n", pedido->id);
        pedido_carne(pedido);
        break;

        case PEDIDO__SIZE:
        free(pedido);
        break;
    }
    return NULL;
}

#endif
