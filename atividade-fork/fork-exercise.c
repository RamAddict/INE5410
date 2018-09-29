#include <sys/wait.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

int first_proc_id;
int ex_count = 1;

int fork_with_print() {
  int prior_id = getpid();
  int id = fork();
  if (id == 0) {
    printf("fork,%d,%d\n", getpid(), prior_id);
    fflush(stdout);
  } else {
    // printf("I am process %d, parent of %d!\n I have just forked it!\n", getpid(), id);
  }
  return id;
}

void finish_exercise() {
  while (wait(NULL) > 0);
  printf("start,%d,%d\n", ex_count, getpid());
  fflush(stdout);
  ex_count++;
}

void exercise_1() {
  for (int i = 0; i < 3; ++i) {
    if (!fork_with_print()) {
      exit(EXIT_SUCCESS);
    }
  }
  finish_exercise();
}

void exercise_2() {
  int a = 1;
  int b = 0;
  int c = 0;
  a = fork_with_print();
  // faz denovo com q o b seja 1 pro pai
  if (a != 0) {
    b = 1;
  }
  a = fork_with_print();
  // faz com que o c seja 2 pro pai
  if (a != 0 && b == 1) {
    c = 2;
  }
  a = fork_with_print();
  if ( a != 0 && c == 2) {
    while(wait(NULL) > 0);
    finish_exercise();
  } else {
    while(wait(NULL) > 0);
    exit(1);
  }

}

void exercise_3() {
  int b = 0;
  int a = 0;
  int c = 2;
  int pid_pai = getpid();
  b = fork_with_print();
  if (b != 0) {
    b = fork_with_print();
  }
  if (b == 0) {
    a = fork_with_print();
    if (a == 0) {
      c = 1;
    }
    if (c == 2) {
    a = fork_with_print();
    }
  }
  if (getpid() != pid_pai) {
    while(wait(NULL) > 0);
    exit(1);
  }
    while(wait(NULL) > 0);
    finish_exercise();
}

void exercise_4() {
  int b = 0;
  int a = 0;
  int c = 2;
  int pid_pai = getpid();
  b = fork_with_print();
  if (b != 0) {
    b = fork_with_print();
  }
  if (b == 0) {
    a = fork_with_print();
    if (a == 0) {
      c = 1;
    }
    if (c == 2) {
    a = fork_with_print();
    }
  }
  if (getpid() == pid_pai) {
    fork_with_print();
  }
  if (getpid() == pid_pai) {
    while(wait(NULL) > 0);
    finish_exercise();
  } else {
    while(wait(NULL) > 0);
    exit(1);
  }

}

void exercise_5() {
  int pid_pai = getpid();
  int a = 0;
  int b = 0;
  int c = 0;
  int d = 0;
  a = fork_with_print();
  if (a == 0) {
    c = 1;
  }
  a = fork_with_print();
  if (a == 0) {
    d = 3;
  }
  if (getpid() != pid_pai) {
    a = fork_with_print();
    b = 2;
  }
  if (d == 0 && c == 1 && b == 2 && a == 0) {
    a = fork_with_print();
  }
  if(c == 0 && b == 2 && d == 3 && a == 0) {
    a = fork_with_print();
    if (a != 0) {
      a = fork_with_print();
    }
  }
  if(getpid() == pid_pai) {
    while(wait(NULL) > 0);
    finish_exercise();
  } else {
  while(wait(NULL) > 0);
  exit(1);
  }
}

void exercise_6() {
  int pid_pai = getpid();
  int a = 0;
  int b = 0;
  int c = 0;
  int d = 0;
  a = fork_with_print();
  if (a == 0) {
      b = 1;
  }
  a = fork_with_print();
  if (a == 0) {
    c = 2;
  }
  if (getpid() != pid_pai) {
    if (a != 0 || b != 0 || c != 2 || d != 0) {
      a = fork_with_print();
      d = 3; 
    }
  }
  if (b == 1 && c == 2 && d == 0) {
    a = fork_with_print();
  }
  if (pid_pai == getpid()) {
    while(wait(NULL) > 0);
    finish_exercise();
  } else {
    while(wait(NULL) > 0);
    exit(1);
  }
}

void exercise_7() {
int a = 0;
//int b = 0;
int pid_pai = getpid();
for (int i = 0; i != 3; i++) {
  if (getpid() == pid_pai) {
  a = fork_with_print();
  }
  
}
if ((getpid() != pid_pai)) {
  a = fork_with_print();
  if (a == 0) {
    a = fork_with_print();
    if (a != 0) {
      a = fork_with_print();
    }
  }
}
if (pid_pai == getpid()) {
    while(wait(NULL) > 0);
    finish_exercise();
  } else {
    while(wait(NULL) > 0);
    exit(1);
  }
}

void exercise_8() {
  int pid_pai = getpid();
  int b = 0;
  int a = fork_with_print();
  if (a == 0) {
    b = 1;
    for (int i = 0; i != 3; i++) {
      if (b = 1) {
        a = fork_with_print();
      } else {
        if (i == 0) {
          a = 10;
        } else if (i == 1) {
          a = 11;
        } else 
        
      }
    }
  }
  finish_exercise();
}

int main (int argc, char** argv) {
  printf("start,%d,%d\n",ex_count, getpid());
  ex_count++;
  first_proc_id = getpid();
  fflush(stdout);
  exercise_1();
  exercise_2();
  exercise_3();
  exercise_4();
  exercise_5();
  exercise_6();
  exercise_7();
  exercise_8();
  printf("end,0,8\n");
  return 0;
}
