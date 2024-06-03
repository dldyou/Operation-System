#import "template.typ": *

#show: project.with(title: title, authors: authors,)

#let img(src, width:100%) = {
    figure(
        image("img/" + src + ".png", width: width)
    )
}
     
= 14-Concurrency and Threads
== Threads
- Multi-threaded 프로그램
    - 스레드 하나의 상태는 프로세스의 상태와 매우 비슷하다.
        - 각 스레드는 그것의 PC(Program Counter)와 private한 레지스터를 가지고 있다.
        - 스레드 당 하나의 스택을 가지고 있다.
    - 같은 address space를 공유하므로 같은 데이터를 접근할 수 있다.
    - Context Switch
        - Thread Control Block (TCB)
        - 같은 address space에 남아있다. (switch를 하는데 page table이 필요하지 않음)

#img("image")

- 사용하는 이유
    - 병렬성
        - Multiple CPUs
    - Blocking 회피
        - 느린 I/O
        - 프로그램에서 하나의 스레드가 기다리는 동안(I/O 작업을 위해 blocked 되어), CPU 스케줄러가 다른 스레드를 실행시킬 수 있다.
    - 많은 현대 서버 기반 어플리케이션은 멀티스레드를 사용하도록 구현되어 있다.
        - 웹 서버, 데이터베이스 관리 시스템, ...

=== Thread Create
#prompt(```c
void *mythread(void *arg)
{
    printf("%s\n", (char *) arg);
    return NULL;
}
int main(int argc, char *argv[])
{
    pthread_t p1, p2;
    int rc;
    printf("main: begin\n");
    rc = pthread_create(&p1, NULL, mythread, "A"); assert(rc == 0);
    rc = pthread_create(&p2, NULL, mythread, "B"); assert(rc == 0);
    // join waits for the threads to finish
    rc = pthread_join(p1, NULL); assert(rc == 0);
    rc = pthread_join(p2, NULL); assert(rc == 0);
    printf("main: end\n");
    return 0;
}
```)

- 실행 가능한 순서

#img("image-1")

- 공유 데이터

#prompt(```c
static volatile int counter = 0;
void * mythread(void *arg)
{
    int i;
    printf("%s: begin\n", (char *) arg);
    for (i = 0; i < 1e7; i++) {
        counter = counter + 1;
    }
    printf("%s: done\n", (char *) arg);
    return NULL;
}
int main(int argc, char *argv[])
{
    pthread_t p1, p2;
    printf("main: begin (counter = %d)\n", counter);
    pthread_create(&p1, NULL, mythread, “A”);
    pthread_create(&p2, NULL, mythread, "B");
    pthread_join(p1, NULL);
    pthread_join(p2, NULL);
    printf("main: done with both (counter = %d)\n", counter);
    return 0;
} 
```)
- 실행 결과
    - counter 값이 2e7이 아닌 다른 값이 나올 수 있다.
#prompt(```bash
main: done with both (counter = 20000000)
main: done with both (counter = 19345221)
main: done with both (counter = 19221041) 
```)
=== Race Condition

#img("image-2")

=== Critical Section
- Critical Section
    - 공유된 자원에 접근하는 코드 영역 (공유 변수)
    - 둘 이상의 스레드에 의해 동시에 실행되어서는 안 된다.
- Mutual Exclusion
    - 한 스레드가 critical section에 들어가면 다른 스레드는 들어갈 수 없다.

=== Atomicity
- Atomic
    - 한 번에 실행되어야 하는 연산
        - 하나의 명령이 시작되었다면 해당 명령이 종료될 때까지 다른 명령이 시작되어서는 안 된다.
- synchronizaion을 어떻게 보장하는지
    - 하드웨어 지원 (atomic instructions)
        - Atomic memory add -> 있음
        - Atomic update of B-tree -> 없음
    - OS는 이러한 명령어들에 따라 일반적인 동기화 primitive 집합을 구현한다.
    
=== Mutex
위의 Atomicity를 보장하기 위해 Mutex를 사용한다.
- Initialization
    - Static: `pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;`
    - Dynamic: `pthread_mutex_init(&lock, NULL);`
- Destory
    - `pthread_mutex_destroy();`
- Condition Variables
    - `int pthread_cond_wait(pthread_cond_t *cond, pthread_mutex_t *mutex);`
        - 조건이 참이 될 때까지 대기하는 함수
        - `pthread_mutex_lock`으로 전달할 mutex을 잠근 후에 호출되어야 한다.
    - `int pthread_cond_signal(pthread_cond_t *cond);`
        - 대기 중인 스레드에게 signal을 보내는 함수
        - `pthread_cond_wait`로 대기 중인 스레드 중 하나를 깨운다. 
    - 외부를 lock과 unlock으로 감싸줘야 한다.
- 두 스레드를 동기화

#prompt(```c
while (read == 0) 
    ; // spin
```)

#prompt(```c
ready = 1;
```)
- 오랜 시간 spin하게 되어 CPU 자원을 낭비하게 된다.
- 오류가 발생하기 쉽다.
    - 현대 하드웨어의 메모리 consistency 모델 취약성
    - 컴파일러 최적화

#prompt(```c
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t cond = PTHREAD_COND_INITIALIZER;
pthread_mutex_lock(&lock);
while (ready == 0)
    pthread_cond_wait(&cond, &lock);
pthread_mutex_unlock(&lock);
```)

#prompt(```c
pthread_mutex_lock(&lock);
ready = 1;
pthread_cond_signal(&cond);
pthread_mutex_unlock(&lock);
```)

- `#include <pthread.h>` 컴파일 시 `gcc -o main main.c -Wall -pthread` 와 같이 진행

= 15-Locks
== Pthread Locks
#prompt(```c
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
...
pthread_mutex_lock(&lock);
counter = counter + 1; // critical section
pthread_mutex_unlock(&lock);
```)

- Lock을 어떻게 설계해야 할까?
    - 하드웨어 / OS 차원에서의 지원이 필요한가?

=== Evaluting Locks
- 상호 배제(Mutual Exclution)
    - 둘 이상의 스레드가 동시에 critical section에 들어가는 것을 방지
- 공평(Fairness)
    - lock을 두고 경쟁할 때, lock이 free가 되었을 때, lock을 얻는 기회가 공평함
- 성능(Performance)
    - lock을 사용함으로써 생기는 오버헤드
        - 스레드의 수
        - CPU의 수

=== Controlling Interrupts
#prompt(```c
void lock() {
    DisableInterrupts();
}
void unlock() {
    EnableInterrupts();
}
```)

- 이러한 모델은 간단하지만 많은 단점이 있음
    - thread를 호출하는 것이 반드시 privileged operation으로 수행되어야 함
    - 멀티프로세서 환경에서 작동하지 않음
    - 인터럽트가 손실될 수 있음
- 한정된 contexts에서만 사용될 수 있음
    - 지저분한 인터럽트 처리 상황을 방지하기 위해

== Support for Locks
=== Hardware Support
- 간단한 방법으로는 `yield()`(본인이 ready큐로, 즉 CPU자원을 포기한다고 함)를 사용할 수 있음
    - 그러나 여전히 비용이 높고 공평하지 않음
        - RR에 의해 스케줄 된 많은 스레드가 있는 상황을 고려해보자
#prompt(```c
void lock(lock_t *lock) {
    while (TestAndSet(&lock->flag, 1) == 1)
        yield();
}
```)

- 하드웨어 만으로는 상호 배제 및 공평성만 해결 할 수 있었음
    - 성능 문제는 여전히 존재 -> OS의 도움이 필요

==== Spin Locks
===== Loads / Stores
#prompt(```c
typedef struct __lock_t { int flag; } lock_t;

void init(lock_t *mutex) {
    // 0 -> lock is available, 1 -> held
    mutex->flag = 0;
}

void lock(lock_t *mutex) {
    while (mutex->flag == 1) // TEST the flag
        ; // spin-wait (do nothing)
    mutex->flag = 1; // now SET it!
}

void unlock(lock_t *mutex) {
    mutex->flag = 0;
}
```)

- 상호 배제가 없음
    - thread 1에서 lock()을 호출하고 while(flag == 1)에서 1이 아니구나 하고 빠져나갈 때 context switch가 일어남
    - thread 2에서 lock()을 호출하고 while(flag == 1)에서 1이 아니구나 하고 빠져나가서 flag = 1로 만듦 
    - context switch가 일어나 thread 1이 다시 돌아와서 flag = 1이 됨
    - 두 스레드 모두 lock을 얻게 됨
- 성능 문제
    - spin-wait으로 인한 CPU 사용량이 많아짐

===== Test-and-Set
- Test-and-Set atomic instruction
#prompt(```c
int TestAndSet(int *old_ptr, int new) {
    int old = *old_ptr; // fetch old value at old_ptr
    *old_ptr = new; // store ’new’ into old_ptr
    return old; // return the old value
} 

typedef struct __lock_t { int flag; } lock_t;

void init(lock_t *lock) {
    lock->flag = 0;
}

void lock(lock_t *lock) {
    while (TestAndSet(&lock->flag, 1) == 1);
}

void unlock(lock_t *mutex) {
    mutex->flag = 0;
} 
```)

- 공평하지 않음 (starvation이 발생할 수 있음)
- 단일 CPU에서 오버헤드가 굉장히 클 수 있음

===== Compare-and-Swap
- Compare-and-Swap atomic instruction
#prompt(```c
int CompareAndSwap(int *ptr, int expected, int new) {
    int actual = *ptr;
    if (actual == expected)
        *ptr = new;
    return actual;
}

void lock(lock_t *lock) {
    while (CompareAndSwap(&lock->flag, 0, 1) == 1);
}
```)

- Test-and-Set과 동일하게 동작함

==== Ticket Locks
- Fetch-and-Add atomic instruction
    - 번호표 발급으로 생각하면 됨
#prompt(```c
int FetchAndAdd(int *ptr) {
    int old = *ptr;
    *ptr = old + 1;
    return old;
}

typedef struct __lock_t {
    int ticket;
    int turn;
} lock_t;

void lock_init(lock_t *lock) {
    lock->ticket = 0;
    lock->turn = 0;
}

void lock(lock_t *lock) {
    int myturn = FetchAndAdd(&lock->ticket);
    while (lock->turn != myturn);
}

void unlock(lock_t *lock) {
    lock->turn = lock->turn + 1;
}
```)

=== OS Support
- spin을 하는 대신 sleep을 함
- Solaris
    - `park()`: 호출한 스레드를 sleep 상태로 만듦
    - `unpark(threadID)`: `threadID`의 스레드를 깨움
- Linux
    - `futex_wait(address, expected)`: address가 expected랑 같다면 sleep 상태로 만듦
    - `futex_wake(address)`: queue에서 스레드 하나를 깨움

==== Locks with Queues (Hardware + OS Support)
#prompt(```c
typedef struct __lock_t {
    int flag; // lock
    int guard; // spin-lock around the flag and
    // queue manipulations
    queue_t *q;
} lock_t;
void lock_init(lock_t *m) {
    m->flag = 0;
    m->guard = 0;
    queue_init(m->q);
}

void lock(lock_t *m) {
    while (TestAndSet(&m->guard, 1) == 1);
    if (m->flag == 0) {
        m->flag = 1; // lock is acquired
        m->guard = 0;
    }
    else {
        queue_add(m->q, gettid());
        m->guard = 0;
        park(); // wakeup/waiting race
    }
}

void unlock(lock_t *m) {
    while (TestAndSet(&m->guard, 1) == 1);
    if (queue_empty(m->q))
        m->flag = 0;
    else
        unpark(queue_remove(m->q));
    m->guard = 0;
}
```)

setpark를 미리 불러주는 모습을 볼 수 있음

#prompt(```c
void lock(lock_t *m) {
    while (TestAndSet(&m->guard, 1) == 1);
    if (m->flag == 0) {
        m->flag = 1; // lock is acquired
        m->guard = 0;
    }
    else {
        queue_add(m->q, gettid());
        setpark(); // another thread calls unpark before
        m->guard = 0; // park is actually called, the
        park(); // subsequent park returns immediately
    }
}
void unlock(lock_t *m) {
    while (TestAndSet(&m->guard, 1) == 1);
    if (queue_empty(m->q))
        m->flag = 0;
    else
        unpark(queue_remove(m->q));
    m->guard = 0;
}
```)

= 16-Lock-Based Concurrent Data Structures
- Correctness
    - 올바르게 작동하려면 lock을 어떻게 추가해야 할까? (어떻게 thread safe하게 만들 수 있을까?)
- Concurrency
    - 자료구조가 높은 성능을 발휘하고 많은 스레드가 동시에 접근할 수 있도록 하려면 lock을 어떻게 추가해야 할까?

== Counter
=== Concurrent Counters
#prompt(```c
typedef struct __counter_t {
    int value;
    pthread_mutex_t lock;
} counter_t;

void init(counter_t *c) {
    c->value = 0;
    pthread_mutex_init(&c->lock, NULL);
}

void increment(counter_t *c) {
    pthread_mutex_lock(&c->lock);
    c->value++;
    pthread_mutex_unlock(&c->lock);
}

void decrement(counter_t *c) {
    pthread_mutex_lock(&c->lock);
    c->value--;
    pthread_mutex_unlock(&c->lock);
}

int get(counter_t *c) {
    pthread_mutex_lock(&c->lock);
    int rc = c->value;
    pthread_mutex_unlock(&c->lock);
    return rc;
}
```)
- 간단하게 생각해보면 이렇게 구현할 수 있을 것이다. 그러나 매 count마다 lock 을 걸어줘야 하므로 concurrency가 떨어진다.

=== Sloppy Counters
- Logical counter
    - Local counter가 각 CPU 코어마다 존재
    - Global counter
    - Locks (각 local counter마다 하나, global counter에도 하나)
- 기본 아이디어
    - 각 CPU 코어마다 local counter를 가지고 있다가 global counter에 값을 옮기는 방식
        - 이는 일정 주기마다 이루어짐
    - global counter에 값을 옮기는 동안 lock을 걸어서 다른 코어가 접근하지 못하도록 함

#prompt(```c
typedef struct __counter_t {
    int global;
    pthread_mutex_t glock;
    int local[NUMCPUS];
    pthread_mutex_t llock[NUMCPUS];
    int threshold; // update frequency
} counter_t;

void init(counter_t *c, int threshold) {
    c->threshold = threshold;
    c->global = 0;
    pthread_mutex_init(&c->glock, NULL);
    int i;
    for (i = 0; i < NUMCPUS; i++) {
        c->local[i] = 0;
        pthread_mutex_init(&c->llock[i], NULL);
    }
}

void update(counter_t *c, int threadID, int amt) {
    int cpu = threadID % NUMCPUS;
    pthread_mutex_lock(&c->llock[cpu]); // local lock
    c->local[cpu] += amt; // assumes amt>0
    if (c->local[cpu] >= c->threshold) {
        pthread_mutex_lock(&c->glock);// global lock
        c->global += c->local[cpu];
        pthread_mutex_unlock(&c->glock);
        c->local[cpu] = 0;
    }
    pthread_mutex_unlock(&c->llock[cpu]);
}

int get(counter_t *c) {
    pthread_mutex_lock(&c->glock); // global lock
    int val = c->global;
    pthread_mutex_unlock(&c->glock);
    return val; // only approximate!
}
```)
== Concurrent Data Structures
=== Linked Lists
#img("image-3", width: 50%)
#img("image-4", width: 50%)
#prompt(```c
typedef struct __node_t {
    int key;
    struct __node_t *next;
} node_t;

typedef struct __list_t {
    node_t *head;
    pthread_mutex_t lock;
} list_t;

void List_Init(list_t *L) {
    L->head = NULL;
    pthread_mutex_init(&L->lock, NULL);
}

int List_Insert(list_t *L, int key) {
    pthread_mutex_lock(&L->lock);
    node_t *new = malloc(sizeof(node_t));
    if (new == NULL) {
        perror("malloc");
        pthread_mutex_unlock(&L->lock);
        return -1; // fail
    }
    new->key = key;
    // mutex lock은 여기로 옮겨지는 것이 좋음 (critical section이 여기부터)
    new->next = L->head;
    L->head = new;
    pthread_mutex_unlock(&L->lock);
    return 0; // success
}

int List_Lookup(list_t *L, int key) {
    pthread_mutex_lock(&L->lock);
    node_t *curr = L->head;
    while (curr) {
        if (curr->key == key) {
            pthread_mutex_unlock(&L->lock);
            return 0; // success (그러나 ret = 0을 저장해놓고 break한 다음에 마지막에 return ret을 하는 것이 좋음 -> 버그 찾기 쉬움)
        }
        curr = curr->next;
    }
    pthread_mutex_unlock(&L->lock);
    return -1; // failure
}
```)

==== Scaling Linked Lists
- Hand-over-hand locking (lock coupling)
    - 각 노드에 대해 lock을 추가 (전체 list에 대한 하나의 lock을 갖는 대신)
    - list를 탐색할 때, 다음 노드의 lock을 얻고 현재 노드의 lock을 해제
    - 각 노드에 대해 lock을 얻고 해제하는 오버헤드 존재
- Non-blocking linked list
    - compare-and-swap(CAS) 이용
#prompt(```c
void List_Insert(list_t *L, int key) {
    ...
RETRY: next = L->head;
    new->next = next;
    if (CAS(&L->head, next, new) == 0)
        goto RETRY;
}
```)
=== Queues
#prompt(```c
typedef struct __node_t {
    int value;
    struct __node_t *next;
} node_t;

typedef struct __queue_t {
    node_t *head; // out
    node_t *tail; // in
    pthread_mutex_t headLock;
    pthread_mutex_t tailLock;
} queue_t;

void Queue_Init(queue_t *q) {
    node_t *tmp = malloc(sizeof(node_t)); // dummy node (head와 tail 연산의 분리를 위해)
    tmp->next = NULL;
    q->head = q->tail = tmp;
    pthread_mutex_init(&q->headLock, NULL);
    pthread_mutex_init(&q->tailLock, NULL);
}
```)

#img("image-5", width: 50%)

#prompt(```c
void Queue_Enqueue(queue_t *q, int value) {
    node_t *tmp = malloc(sizeof(node_t));
    assert(tmp != NULL);
    tmp->value = value;
    tmp->next = NULL;
    pthread_mutex_lock(&q->tailLock);
    q->tail->next = tmp;
    q->tail = tmp;
    pthread_mutex_unlock(&q->tailLock);
}
```)

#img("image-6", width: 50%)

- 길이가 제한된 큐에서는 제대로 작동하지 않음, 조건 변수에 대해서는 다음 장에서 다루게 될 예정

#prompt(```c
int Queue_Dequeue(queue_t *q, int *value) {
    pthread_mutex_lock(&q->headLock);
    node_t *tmp = q->head;
    node_t *newHead = tmp->next;
    if (newHead == NULL) {
        pthread_mutex_unlock(&q->headLock);
        return -1; // queue was empty
    }
    *value = newHead->value;
    q->head = newHead;
    pthread_mutex_unlock(&q->headLock);
    free(tmp);
    return 0;
}
```)

#img("image-7")

=== Hash Table
#prompt(```c
#define BUCKETS (101)
typedef struct __hash_t {
    list_t lists[BUCKETS]; // 앞에서 본 list_t를 사용
} hash_t;
void Hash_Init(hash_t *H) {
    int i;
    for (i = 0; i < BUCKETS; i++)
        List_Init(&H->lists[i]);
}
int Hash_Insert(hash_t *H, int key) {
    int bucket = key % BUCKETS;
    return List_Insert(&H->lists[bucket], key);
}
int Hash_Lookup(hash_t *H, int key) {
    int bucket = key % BUCKETS;
    return List_Lookup(&H->lists[bucket], key);
}
```)

= 17-Condition Variables
스레드를 계속 진행하기 전에 특정 조건이 true가 될 때까지 기다리는 것이 유용한 경우가 많다. 그러나, condition이 true가 될 때까지 그냥 spin만 하는 것은 CPU cycle을 낭비하게 되고 이것은 부정확할 수 있다.

#prompt(```c
volatile int done = 0;
void *child(void *arg) {
    printf("child\n");
    done = 1;
    return NULL;
}
int main(int argc, char *argv[]) {
    pthread_t c;
    printf("parent: begin\n");
    pthread_create(&c, NULL, child, NULL); // create child
    while (done == 0); // spin
    printf("parent: end\n");
    return 0;
}
```)

== Condition Variable
- condition 변수는 명시적인 대기열과도 같다.
    - 스레드는 일부 상태(즉, 일부 condition)가 원하는 것과 다를 때 대기열에 들어갈 수 있다.
    - 몇몇 스레드는 상태가 변경되면, 대기열에 있는 스레드 중 하나(또는 그 이상)를 깨워 진행되도록 할 수 있다.
    - `pthread_cond_wait();`
        - 스레드가 자신을 sleep 상태로 만들려고 할 때 사용
            - lock을 해제하고 호출한 스레드를 sleep 상태로 만든다. (atomic하게)
            - 스레드가 깨어나면 반환하기 전에 lock을 다시 얻는다.
    - `pthread_cond_signal();`
        - 스레드가 프로그램에서 무언가를 변경하여 sleep 상태인 스레드를 깨우려고 할 때 사용

#prompt(```c
int done = 0;
pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t c = PTHREAD_COND_INITIALIZER;

void *child(void *arg) {
    printf("child\n");
    thr_exit();
    return NULL;
}

int main(int argc, char *argv[]) {
    pthread_t p;
    printf("parent: begin\n");
    pthread_create(&p, NULL, child, NULL);
    thr_join();
    printf("parent: end\n");
    return 0;
}
```)

#prompt(```c
void thr_exit() {
    pthread_mutex_lock(&m);
    done = 1;
    pthread_cond_signal(&c);
    pthread_mutex_unlock(&m);
}

void thr_join() {
    pthread_mutex_lock(&m);
    while (done == 0)
        pthread_cond_wait(&c, &m);
    pthread_mutex_unlock(&m);
}
```)

- 만약 여기서 상태 변수인 `done`이 없으면?
    - child가 바로 실행되고 thr_exit()을 호출하면?
        - child가 signal을 보내지만 그 상태에서 잠들어 있는 스레드가 없다.
- 만약 lock이 없다면?
    - child가 parent가 wait을 실행하기 직전에 signal을 보내면?
        - waiting 상태에 있는 스레드가 없으므로 깨어나는 스레드가 없다.

=== Producer / Consumer Problem
- Producers
    - 데이터를 생성하고 그들을 (제한된) 버퍼에 넣는다.
- Consumers
    - 버퍼에서 데이터를 가져와서 그것을 소비한다.
- 예시 
    - Pipe
        - `grep foo file.txt | wc -l`
    - Web server
- 제한된 버퍼가 공유 자원이기에 당연히 이에 대한 동기화된 접근이 필요하다.

#prompt(```c
int buffer; // single buffer
int count = 0; // initially, empty
void put(int value) {
    assert(count == 0);
    count = 1;
    buffer = value;
}
int get() {
    assert(count == 1);
    count = 0;
    return buffer;
}
```)

#prompt(```c
cond_t cond;
mutex_t mutex;
void *producer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        pthread_mutex_lock(&mutex); // p1
        if (count == 1) // p2
            pthread_cond_wait(&cond, &mutex); // p3
        put(i); // p4
        pthread_cond_signal(&cond); // p5
        pthread_mutex_unlock(&mutex); // p6
    }
}
```)

#prompt(```c
void *consumer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        pthread_mutex_lock(&mutex); // c1
        if (count == 0) // c2
            pthread_cond_wait(&cond, &mutex); // c3
        int tmp = get(); // c4
        pthread_cond_signal(&cond); // c5
        pthread_mutex_unlock(&mutex); // c6
        printf("%d\n", tmp);
    }
}
```)

- 단일 producer와 단일 consumer로 진행한다고 하자. 

#img("image-8")

- 위 그림에서 알 수 있듯이 $T_(c 1)$가 다시 깨어나 실행될 때 state가 여전히 원하던 값이라는 보장이 없다.
- count를 체크하는 부분을 if문에서 while문으로 바꾸어주면 아래와 같이 돌아간다.

#img("image-9")

- consumer는 다른 consumer를 깨우면 안 되고, producer만 깨우면 되고, 반대의 경우도 마찬가지이다. 위의 경우는 그것이 안 지켜져서 모두가 잠들어버린 상황이다.
- 이는 condition 변수를 하나를 사용하기에 발생하는 문제이다. (같은 큐에 잠들기에 producer를 깨우고자 했으나 다른 결과를 야기할 수 있음)
    - `p3`의 cv를 `&empty`로 `c5`의 cv를 `&full`로 바꾸어주면 해결된다.

#prompt(```c
int buffer[MAX];
int fill_ptr = 0;
int use_ptr = 0;
int count = 0;

void put(int value) {
    buffer[fill_ptr] = value;
    fill_ptr = (fill_ptr + 1) % MAX;
    count++;
}

int get() {
    int tmp = buffer[use_ptr];
    use_ptr = (use_ptr + 1) % MAX;
    count--;
    return tmp;
}
```)

- 이와 같이 버퍼를 만들고 producer에서 `count == MAX`로 바꾸어주면 동시성과 효율성을 챙길 수 있다.

- Covering Conditions
    - `pthread_cond_broadcast()`
        - 대기 중인 모든 스레드를 깨운다.

= 18-Semaphores
- 세마포어는 lock이나 condition 변수를 통해 사용할 수 있다.
- POSIX Semaphores
    - `int sem_init(sem_t *s, int pshared, unsigned int value);`
        - pshared가 0이면 프로세스 내에서만 사용 가능하고, 1이면 프로세스 간에도 사용 가능하지만, 공유 메모리에 있어야 한다.
    - `int sem_wait(sem_t *s);`
        - 세마포어 값을 감소시키고, 값이 0보다 작으면 대기한다.
    - `int sem_post(sem_t *s);`
        - 세마포어 값을 증가시킨다.
        - 만약 대기 중인 스레드가 있다면 하나를 깨운다.
- Binary Semaphores (lock이랑 비슷함)
#prompt(```c
sem_t m;
sem_init(&m, 0, 1);

sem_wait(&m);
// critical section here
sem_post(&m);
```)

#img("image-10")

- Semaphores for Ordering
세마포어를 사용해 스레드간의 순서를 정할 수 있다.

#prompt(```c
sem_t s;
void * child(void *arg) {
    printf("child\n");
    sem_post(&s);
    return NULL;
}
int main(int argc, char *argv[]) {
    pthread_t c;
    sem_init(&s, 0, X); // what should X be?
    printf("parent: begin\n");
    pthread_create(&c, NULL, child, NULL);
    sem_wait(&s);
    printf("parent: end\n");
    return 0;
}
```)

- X는 0이어야 한다. 그래야 다음 `sem_wait`이 바로 실행되더라도 세마포어 값이 음수가 되며 잠들 수 있고, child가 먼저 실행되어 post를 실행하여 세마포어 값이 1이 되고 `sem_wait`가 실행되더라도 잠에 들지 않아 deadlock이 발생하지 않는다.

#img("image-11")

== Producer / Consumer Problem

#prompt(```c
int buffer[MAX]; // bounded buffer
int fill = 0;
int use = 0;

void put(int value) {
    buffer[fill] = value;
    fill = (fill + 1) % MAX;
}

int get() {
    int tmp = buffer[use];
    use = (use + 1) % MAX;
    return tmp;
}

sem_t empty, sem_t full;
void *producer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        sem_wait(&empty);
        put(i);
        sem_post(&full);
    }
}

void *consumer(void *arg) {
    int i, tmp = 0;
    while (tmp != -1) {
        sem_wait(&full);
        tmp = get();
        sem_post(&empty);
        printf("%d\n", tmp);
    }
}

int main(int argc, char *argv[]) {
    // ...
    sem_init(&empty, 0, MAX); // MAX are empty
    sem_init(&full, 0, 0); // 0 are full
    // ...
}
```)

- Race Condition이 발생한다.
    - 생산자와 소비자가 여럿인 경우 `put()`과 `get()`에서 race condition이 발생한다.

#prompt(```c
void *producer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        sem_wait(&mutex); // 2
        sem_wait(&empty);
        put(i);
        sem_post(&full);
        sem_post(&mutex);
    }
}
void *consumer(void *arg) {
    int i;
    for (i = 0; i < loops; i++) {
        sem_wait(&mutex);
        sem_wait(&full); // 1
        int tmp = get();
        sem_post(&empty);
        sem_post(&mutex);
    }
}
```)

- 이렇게 mutex를 추가하면 deadlock이 발생한다.
    - 소비자가 먼저 실행되어 wait에 의해 mutex를 0으로 감소시키고 1까지 실행되어 sleep을 하게 된다.
    - 생산자가 실행되고, wait에 의해 mutex가 -1이 되어 잠들게 된다.
    - 둘 다 잠들어버리게 되어 deadlock이 발생한다.
- *mutex를 모두 안쪽으로 옮겨주면 해결된다.* 

== Reader / Writer Locks
- Reader 
    - `rwlock_acquire_readlock()`
    - `rwlock_release_readlock()`
- Writer
    - `rwlock_acquire_writelock()`
    - `rwlock_release_writelock()`

#prompt(```c
typedef struct _rwlock_t {
    // binary semaphore (basic lock)
    sem_t lock;
    // used to allow ONE writer or MANY readers
    sem_t writelock;
    // count of readers reading in critical section
    int readers;
} rwlock_t;

void rwlock_init(rwlock_t *rw) {
    rw->readers = 0;
    sem_init(&rw->lock, 0, 1);
    sem_init(&rw->writelock, 0, 1);
}

void rwlock_acquire_writelock(rwlock_t *rw) {
    sem_wait(&rw->writelock);
}

void rwlock_release_writelock(rwlock_t *rw) {
    sem_post(&rw->writelock);
}

void rwlock_acquire_readlock(rwlock_t *rw) {
    sem_wait(&rw->lock);
    rw->readers++;
    if (rw->readers == 1)
        // first reader acquires writelock
        sem_wait(&rw->writelock);
    sem_post(&rw->lock);
}

void rwlock_release_readlock(rwlock_t *rw) {
    sem_wait(&rw->lock);
    rw->readers--;
    if (rw->readers == 0)
        // last reader releases writelock
        sem_post(&rw->writelock);
    sem_post(&rw->lock);
}
```)

- reader에게 유리함 (writer가 굶을 수 있음)

== How To Implement Semaphores
#prompt(```c
typedef struct __Sem_t {
    int value;
    pthread_cond_t cond;
    pthread_mutex_t lock;
} Sem_t;

// only one thread can call this
void Sem_init(Sem_t *s, int value) {
    s->value = value;
    Cond_init(&s->cond);
    Mutex_init(&s->lock);
}

void Sem_wait(Sem_t *s) {
    Mutex_lock(&s->lock);
    while (s->value <= 0)
        Cond_wait(&s->cond, &s->lock);
    s->value--;
    Mutex_unlock(&s->lock);
}

void Sem_post(Sem_t *s) {
    Mutex_lock(&s->lock);
    s->value++;
    Cond_signal(&s->cond);
    Mutex_unlock(&s->lock);
}
```)

- 원래 구현: 값이 음수인 경우 대기 중인 스레드의 수를 반영
- Linux: 값은 0보다 낮아지지 않음