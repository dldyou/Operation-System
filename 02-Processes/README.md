# Processes(1)
## 프로그램 vs. 프로세스
`프로그램` 
- 디스크에 많은 명령어와 데이터가 들어 있음

`프로세스`
- 프로그램을 실행한 것
- Machine state
    - 메모리: 명령어와 데이터
    - 레지스터: PC(Program Counter), SP(Stack Pointer), ...
    - 나머지: 프로세스가 열고 있는 파일의 목록

`APIs`
- 생성, 종료, 중지, 기타 제어 및 상태

## System Calls 

### `fork()` System Call
```C
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(int argc, char *argv[]) {
    printf("hello world (pid:%d)\n", (int)getpid());
    int rc = fork();
    if (rc < 0) {
        fprintf(stderr, "fork failed\n");
        exit(1);
    }
    else if (rc == 0) {
        printf("I am child (pid:%d)\n", (int)getpid());
    }
    else {
        printf("I am parent of %d (pid:%d)\n",
            rc, (int)getpid());
    }
    return 0;
}
```
```
prompt> ./p1
hello world (pid:29416)
hello, I am parent of 29417 (pid:29416)
hello, I am child (pid:29417)
prompt>
```
```
prompt> ./p1
hello world (pid:29416)
hello, I am child (pid:29417)
hello, I am parent of 29417 (pid:29416)
prompt>
```

### `wait()` System Call
```C
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
int main(int argc, char *argv[]) {
    printf("hello world (pid:%d)\n", (int)getpid());
    int rc = fork();
    if (rc < 0) {
        fprintf(stderr, "fork failed\n");
        exit(1);
    }
    else if (rc == 0) {
        printf("I am child (pid:%d)\n", (int)getpid());
    }
    else {
        int wc = wait(NULL);
        printf("I am parent of %d (wc:%d) (pid:%d)\n",
            rc, wc, (int)getpid());
    }
    return 0;
}
```
```
prompt> ./p2
hello world (pid:29266)
hello, I am child (pid:29267)
hello, I am parent of 29267 (wc:29267) (pid:29266)
prompt>
```

### `exec()` System Call
```C
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/wait.h>
int main(int argc, char *argv[]) {
    printf("hello world (pid:%d)\n", (int)getpid());
    int rc = fork();
    if (rc < 0) {
        fprintf(stderr, "fork failed\n");
        exit(1);
    }
    else if (rc == 0) {
        printf("I am child (pid:%d)\n", (int)getpid());
        char *myargs[3];
        myargs[0] = strdup("wc"); // strdup: 문자열 메모리 할당 후 포인터 반환(복사)
        myargs[1] = strdup("p3.c");
        myargs[2] = NULL;
        execvp(myargs[0], myargs);
        printf("this shouldn’t print out");
    }
    else {
        int wc = wait(NULL);
        printf("I am parent of %d (wc:%d) (pid:%d)\n",
            rc, wc, (int)getpid());
    }
    return 0;
}
```
```
prompt> ./p3
hello world (pid:29383)
hello, I am child (pid:29384)
29 107 1030 p3.c
hello, I am parent of 29384 (wc:29384) (pid:29383)
prompt>
```

## 문제의 핵심
- 어떻게 많은 CPU들을 제공하는 것과 같은 착각을 주게 하는지
- 사용 가능한 물리적 CPU는 몇 개에 불과하지만, 어떻게 OS가 끝없는 공급을 해주는 것과 같은 착각을 주게 하는지

### CPU Virtualization
`Time sharing`
- 오직 몇 개의 물리적 CPU가 있더라도, 많은 가상 CPU들이 존재하는 것처럼 보이게 함
- 사용자는 원하는 만큼 많은 프로세스들을 동시에 실행할 수 있음
- 잠재적인 비용
    - CPU가 공유된다면, 각각은 더 느리게 작동함
    - 이것이 이득인가?
- Context Switch 와 스케줄링 정책이 중요함

# Processes (2)
## Process State
`Running`
- 프로세스가 프로세서에서 실행 중

`Ready`
- 프로세스가 ready to run 상태이지만, OS가 이 순간에서 실행하지 않음

`Blocked(Waiting)`
- 프로세스가 ready to run 이 아닌 상태 (다른 이벤트가 진행중, I/O...)

## 자료구조 (Process Control Blocks, PCB)
`Linux kernel` : `/include/linux/sched.h`
```C
struct task_struct {
    volatile long       state; /* TASK_RUNNING, TASK_INTERRUPTIBLE …*/
    void                *stack; /* Pointer to the kernel-mode stack */
    …
    unsigned int        cpu;
    …
    struct mm_struct    *mm;
    …
    struct task_struct  *parent;
    struct list_head    children;
    …
    struct files_struct *files;
    …
}
```
- 각 user process는 `user-mode stack`와 `kernel-mode stack`을 가짐
- thread가 커널에 들어가면 `user-mode` 프로세스로 사용된 모든 레지스터의 내용이 `kernel-mode stack`에 저장됨 (즉, 리눅스는 프로세스의 context 정보를 `kernel-mode stack`에 저장함)

## Scheduling Queues
- OS는 3가지 타입의 큐를 관리
    - `Run queue`
    - `Ready queue`
    - `Wait queue`

예시
> Run queue: $P_0$ <br>
Ready Queue: $P_1$ <br>
Wait Queue:  <br>

>Run queue: $P_1$ <br>
Ready Queue: <br>
Wait Queue: $P_0$ <br>