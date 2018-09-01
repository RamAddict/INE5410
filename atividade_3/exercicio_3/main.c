#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <stdio.h>
#include <pthread.h>

// Lê o conteúdo do arquivo filename e retorna um vetor E o tamanho dele
// Se filename for da forma "gen:%d", gera um vetor aleatório com %d elementos
//
// +-------> retorno da função, ponteiro para vetor malloc()ado e preenchido
// |         usado como 2o retorno! <-----+
// v                                      v
double* load_vector(const char* filename, int* out_size);

struct info {
    double* a;
    double* b;
    double result;
    int position;

};
void* sum(void* data);
int main(int argc, char* argv[]) {
    srand(time(NULL));
    
    //Temos argumentos suficientes?
    if(argc < 4) {
        printf("Uso: %s n_threads a_file b_file\n"
               "    n_threads    número de threads a serem usadas na computação\n"
               "    *_file       caminho de arquivo ou uma expressão com a forma gen:N,\n"
               "                 representando um vetor aleatório de tamanho N\n", 
               argv[0]);
        return 1;
    }
  
    //Quantas threads?
    int n_threads = atoi(argv[1]);
    if (!n_threads) {
        printf("Número de threads deve ser > 0\n");
        return 1;
    }
    //Lê números de arquivos para vetores alocados com malloc
    int a_size = 0, b_size = 0;
    double* a = load_vector(argv[2], &a_size);
    if (!a) {
        //load_vector não conseguiu abrir o arquivo
        printf("Erro ao ler arquivo %s\n", argv[2]);
        return 1;
    }
    double* b = load_vector(argv[3], &b_size);
    if (!b) {
        printf("Erro ao ler arquivo %s\n", argv[3]);
        return 1;
    }
    
    //Garante que entradas são compatíveis
    if (a_size != b_size) {
        printf("Vetores a e b tem tamanhos diferentes! (%d != %d)\n", a_size, b_size);
        return 1;
    }

    pthread_t treds[n_threads];
    struct info data;

    data.a = a;
    data.b = b;

    for (int i = 0; i != a_size; ++i) {
        data.position = i % a_size;
        pthread_create(&treds[i], NULL, sum, (void*)&data); //how does this not work?
        pthread_join(treds[i], NULL);
    }

    
    
    
    
    //Imprime resultado
    printf("Produto escalar: %g\n", data.result);    

    //Libera memória
    free(a);
    free(b);

    return 0;
}
void* sum(void* data) {
    double* a = (*((struct info*) data)).a;
    double* b =  (*((struct info*) data)).b;
    double* result = &(*((struct info*) data)).result;
    int i = (*((struct info*) data)).position;

    *result += a[i] * b[i];
    return NULL;
}