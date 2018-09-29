Instructions available in portuguese only
This didatic material was produced by Vinicius Freitas, for the Concurrent Programming Course at UFSC, 2018/2 (INE5410).

----------------
# Exercício Prático de Fixação - Processos

Este conjunto de 8 exercícios básicos sobre o tema Criação e Finalização de Processos, em programação concorrente, tem como objetivo fixar o conhecimento adquirido em sala nas aulas teóricas e práticas de Programação Concorrente (INE5410).
As instruções a seguir dizem respeito a forma como os arquivos disponibilizados estão organizados para que os estudantes possam realizar esta atividade.

## Instruções para realização

O arquivo "fork-exercise.c" possui 8 chamadas de função de nome "exercise_n()", com n variando de 1 a 8. Estes são os exercícios que devem ser executados nesta atividade. A função "main()" já está preparada para executar todos os exercícios, de forma que nenhuma modificação nela deverá ser necessária.

A atividade consiste na criação de 8 diferentes árvores de processos, uma para cada exercício, contando com algumas regras e restrições:

1) Cada chamada de criação de processo (fork) deve ser feita utilizando a função disponibilizada "fork_with_print()", esta função já gera a saída no formato esperado para que esta seja corrigida.

1.1) O comportamento da função "fork_with_print()" é idêntico ao do "fork()", com a diferença de que este imprime, em formato CSV, algumas informações sobre este novo processo criado que serã usadas para corrigir seu exercício.

2) O processo raíz original (aquele que iniciou a execução do seu programa) deve existir até o final, sendo ele mesmo a raíz de cada uma das árvores de processos.

3) Todos os outros processos devem sair ("exit()") antes do início do próximo exercício, ou seja, CADA PROCESSO DEVE ESPERAR TODOS OS SEUS FILHOS ANTES DE CHAMAR O EXIT()!

3.1) A única exceção para isto é o processo raíz original, que deve chamar a função disponibilizada "finish_exercise()", que irá esperar todos os filhos e iniciar a próxima resolução de exercício.

3.2) Os demais processos podem seguir o protocolo da função "finish_exercise()", usando a função de sistema "wait()" para esperar os seus filhos antes de saírem ("exit()").

4) Não deve haver outras impressões que não as inicialmente previstas na sua entrega final do trabalho.

5) A impressão final do "main()", que adiciona uma linha cujo primeiro item é o token 'end' é crucial para que os exercícios possam ser corrigidos.

### Utilizando Makefile:

Para compilar o seu exercício, utilize o Makefile disponibilizado com a linha:
"make exercise"
O binário terá nome "exercise" e não precisa de parâmetros para ser executado. Este executará todos os seus exercícios, tendo como output o padrão usado na correção.

#### Padrão de impressão:

'start',#exercicio,#pidraiz
'fork',#pidfilho,#pidpai
'end',#,#

Ou seja, start dará o identificador do exercício e o processo que o iniciou.
Fork dará o processo filho e seu pai quando um "fork_with_print" for chamado.
End indicará que a lista de exercícios chegou ao fim.

### Lista de exercícios:

A lista de exercícios pode ser encontrada como um conjunto de imagens de árvores de processos no subdiretório ./img-exercises/
Estas árvores estão representadas como grafos, onde cada nó do grafo é um processo e as arestas direcionadas apontam de pais para filhos.


### Testando seu trabalho:

Caso deseje testar seu trabalho antes da entrega, você pode instalar o Google Test (busque por tutoriais apropriados ao seu sistema operacional) que já tem testes automatizados para os exercícios de 1 até 4.
Caso deseje testar o restante de seu trabalho, refira-se a seção final deste documento (Auxílio do Estagiário de Docência).

### Entrega final:

O ÚNICO arquivo a ser entregue na versão final do trabalho é a sua versão do "fork-exercise.c". Os demais componentes disponibilizados NÃO DEVEM SER MODIFICADOS, pois os utilizados na correção serão os originais.

### Auxílio do Estagiário de Docência:

O estagiário de docência estará disponível na tarde de sexta-feira (24/08) e segunda-feira (27/08) das 14 até às 16 horas para atendimento sem horário marcado. 
Esses momentos podem ser usados para averiguar a corretudo do trabalho completo ou tirar dúvidas sobre como o mesmo será realizado.
Qualquer dúvida referente ao trabalho, ainda não respondida em sala ou em atendimento, postada no FÓRUM DE DISCUSSÃO DO MOODLE será respondida em até 24h pelos estagiários ou professores da disciplina.

O local de atendimento é a sala 417 do prédio do INE.


### Avaliação

A nota final do exercício será igual a quantidade de exercícios corretos (C) multiplicado por 10 e dividido por 8.

NF = 10*C/8

O impacto deste trabalho na avaliação da disciplina ainda precisa ser averiguado pelos professores, mas sua nota será de caráter bonificador, ou seja, só tem como melhor a nota do aluno que o realizar.
