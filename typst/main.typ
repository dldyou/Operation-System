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

= 19-Common Concurrency Problems
== Concurrency Problems
    - Non-deadlock 버그
        - Atomicity 위반
        - 순서 위반
    - deadlock bug

=== Atomicity-Violation
- 메모리 영역에 대해 여러 개의 스레드가 동시에 접근할 때 serializable 해서 race condition이 발생하지 않을 것이라 예상하지만 그렇지 않은 경우가 있다.

- MySQL 버그
#prompt(```c
Thread 1:
if (thd->proc_info) {
    ...
    fputs(thd->proc_info, ...);
    ...
}

Thread 2:
thd->proc_info = NULL;
```)

- Thread 1의 if문을 확인하고 들어왔으나 Thread 2가 값을 NULL로 바꾸어버리면서 fputs에서 비정상 종료가 된다.

- 해결 방법
#prompt(```c
pthread_mutex_t proc_info_lock = PTHREAD_MUTEX_INITIALIZER;

Thread 1:
pthread_mutex_lock(&proc_info_lock);
if (thd->proc_info) {
    ...
    fputs(thd->proc_info, ...);
    ...
}
pthread_mutex_unlock(&proc_info_lock);

Thread 2:
pthread_mutex_lock(&proc_info_lock);
thd->proc_info = NULL;
pthread_mutex_unlock(&proc_info_lock);
```)

=== Order-Violation
- A -> B 스레드 순서로 실행되기를 바랬으나 다르게 실행되는 경우

- Mozilla 버그
#prompt(```c
Thread 1:
void init() {
    ...
    mThread = PR_CreateThread(mMain, ...);
    ...
}
Thread 2:
void mMain(...) {
    ...
    mState = mThread->State;
    ...
}
```)

- Thread 2가 생성되자마자 mState를 읽어버리면서 mThread가 초기화되기 전에 읽어버리는 문제가 발생한다. (Null 포인터를 접근하게 됨)

- 해결 방법
#prompt(```c
pthread_mutex_t mtLock = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t mtCond = PTHREAD_COND_INITIALIZER;
int mtInit = 0;

Thread 1:
void init() {
    ...
    mThread = PR_CreateThread(mMain, ...);

    // signal that the thread has been created...
    pthread_mutex_lock(&mtLock);
    mtInit = 1;
    pthread_cond_signal(&mtCond);
    pthread_mutex_unlock(&mtLock);
    ...
}

Thread 2:
void mMain(...) {
    ...
    // wait for the thread to be initialized...
    pthread_mutex_lock(&mtLock);
    while (mtInit == 0)
        pthread_cond_wait(&mtCond, &mtLock);
    pthread_mutex_unlock(&mtLock);
    mState = mThread->State;
    ...
}
```)

=== Deadlock Bugs
- Circular Dependencies

#prompt(```c
Thread 1:
pthread_mutex_lock(L1);
pthread_mutex_lock(L2);
Thread 2:
pthread_mutex_lock(L2);
pthread_mutex_lock(L1);
```)

#img("image-12", width:50%)

- Thread 1은 L1을 먼저 잡고, Thread 2는 L2를 먼저 잡은 상태에서 서로를 기다리게 되어 deadlock이 발생한다.

- 왜 deadlock이 발생할까?
    - 큰 코드 베이스에서는 컴포넌트 간의 의존성이 복잡함
    - 캡슐화의 특징
        - `Vector v1, v2`
        - `Thread 1: v1.addAll(v2)`
        - `Thread 2: v2.addAll(v1)`

=== Conditions for Deadlock
- Mutual Exclusion
    - 한 번에 하나의 스레드만이 자원을 사용할 수 있음
- Hold and Wait
    - 스레드가 자원을 가지고 있는 상태에서 다른 자원을 기다림
- No Preemption
    - 스레드가 자원을 강제로 뺏을 수 없음
- Circular Wait
    - 스레드 A가 스레드 B가 가지고 있는 자원을 기다리고, 스레드 B가 스레드 A가 가지고 있는 자원을 기다림

==== Deadlock Prevention
- Circular Wait
    - lock acqustition 순서를 정함
- Hold and Wait
    - 모든 자원을 한 번에 요청 (전체를 lock으로 한 번 감싸기)
    - critical section이 커지는 문제가 발생할 수 있었음
    - 미리 lock을 알아야 함
#prompt(```c
pthread_mutex_lock(prevention); // begin lock acquisition
pthread_mutex_lock(L1);
pthread_mutex_lock(L2);
...
pthread_mutex_unlock(prevention); // end
```)

- No Preemption
    - `pthread_mutex_trylock()`: lock을 얻을 수 없으면 바로 반환
    - 아래처럼 구현하면 livelock(deadlock처럼 모든 스레드가 lock을 얻지 못하고 멈췄는데, 코드는 돌아가고 있는 상태)이 발생할 수 있음
        - random delay를 추가해 누군가는 acquire에 성공하도록 할 수 있음
    - 획득한 자원이 있다면 반드시 해제해야 함
        - lock이나 메모리...
#prompt(```c
top:
pthread_mutex_lock(L1);
if (pthread_mutex_trylock(L2) != 0) {
    pthread_mutex_unlock(L1);
    goto top;
}
```)

- Mutual Exclusion
    - race condition을 없애기 위해 mutual exclusion을 사용함
    - 그런데 이거를 없애야 하나? (X) -> lock을 안 쓴다는 것으로 이해하면 됨
    - lock free 접근법 (atomic operation을 이용)

#prompt(```c
int CompareAndSwap(int *address, int expected, int new) {
    if (*address == expected) {
        *address = new;
        return 1; // success
    }
    return 0; // failure
}

void AtomicIncrement(int *value, int amount) {
    do {
        int old = *value;
    } while (CompareAndSwap(value, old, old + amount) == 0);
}
```)

#prompt(```c
void insert(int value) {
    node_t *n = malloc(sizeof(node_t));
    assert(n != NULL);
    n->value = value;
    n->next = head;
    head = n;
}

void insert(int value) {
    node_t *n = malloc(sizeof(node_t));
    assert(n != NULL);
    n->value = value;
    pthread_mutex_lock(listlock);
    n->next = head;
    head = n;
    pthread_mutex_unlock(listlock);
}

void insert(int value) {
    node_t *n = malloc(sizeof(node_t));
    assert(n != NULL);
    n->value = value;
    do {
        n->next = head;
    } while (CompareAndSwap(&head, n->next, n) == 0);
}
```)

= I/O Devices and HDD
== System Architecture
    - CPU / Main Memory 
    - (Memory Bus)
    - (General I/O Bus(PCI))
    - Graphics
    - (주변기기 I/O Bus(SCSI, SATA, USB))
    - HDD
== I/O Devices
    - 인터페이스
        - 시스템 소프트웨어로 작동을 제어할 수 있도록 함
        - 모든 장치는 일반적인 상호작용을 위한 특정 인터페이스와 프로토콜이 있음
    - 내부 구조
        - 시스템에 제공하는 추상화된 구현
#img("image-13")
== Interrupts
- Interrupt로 CPU 오버헤드를 낮춤
    - 장치를 반복적으로 polling 하는 대신 OS 요청을 날리고, 호출한 프로세스를 sleep 상태로 만들고 다른 작업으로 context switch를 함
    - 장치가 최종적으로 작업을 마치면 하드웨어 interrupt를 발생시켜 CPU가 미리 결정된 interrupt service routine(ISR)에서 OS로 넘어가게 함
- Interrupts는 I/O 연산을 하는 동안 CPU를 다른 작업에 사용할 수 있게 함
== Direct Memory Access (DMA)
- DMA를 사용하면 더 효율적인 데이터 이동을 할 수 있다.
    - DMA 엔진은 CPU 개입 없이 장치와 주메모리 간의 전송을 조율할 수 있는 장치이다.
    - OS는 데이터가 메모리에 있는 위치와 복사할 위치를 알려주어 DMA 엔진을 프로그래밍한다.
    - DMA가 완료되면 DMA 컨트롤러는 interrupt를 발생시킨다.
#img("image-14")
== Methods of Device Interaction
- I/O instructions
    - `in` / `out` (x86)
    - 장치에 데이터를 보내기 위해 호출자는 데이터가 포함된 레지스터와 장치 이름을 지정하는 특정 포트를 지정한다.
    - 일반적으로 privileged instruction이다.
- Memory-mapped I/O
    - 하드웨어는 마치 메모리 위치인 것처럼 장치 레지스터를 사용할 수 있게 만든다.
    - 특정 레지스터에 접근하기 위해 OS는 주소를 읽거나 쓴다.

#img("image-15")
== HDD
- 기본 요소
    - Platter
        - 데이터가 지속적으로 저장되는 원형의 단단한 표면
        - 디스크는 하나 또는 그 이상의 platters를 가진다. 각 platter는 `surface`라고 불리는 두 면을 가진다.
    - Spindle
        - platters를 일정한 속도로 회전시키는 모터를 연결
        - 회전 속도는 RPM으로 측정된다. (7200 ~ 15000 RPM)
    - Track
        - 데이터는 각 구역(sector)의 동심원으로 각 표면에 인코딩된다. (512-byte blocks)
    - Disk head and disk arm
        - 읽기 및 쓰기는 디스크 헤드에 의해 수행된다. 드라이브 표면 당 하나의 헤드가 있다.
        - 디스크 헤드는 단일 디스크 암에 부착되어 표면을 가로질러 이동하여 원하는 track 위에 헤드를 배치한다.

#img("image-16")
=== I/O Time
$T_(I \/ O) = T_("seek") + T_("rotation") + T_("transfer")$

- Seek time 
    - 디스크 암을 올바른 트랙으로 옮기는데 걸리는 시간
- Rotational delay
    - 디스크가 올바른 섹터로 회전하는데 걸리는 시간
=== Disk Scheduling
- OS가 디스크로 날릴 I/O 요청들의 순서를 결정한다.
    - I/O 요청의 집합이 주어지면, 디스크 스케줄러는 요청을 검사하고 다음에 무엇을 실행해야 하는지 결정한다.

- 요청: 98, 183, 37, 122, 14, 124, 65, 67 (Head: 53)
    - *FCFS (First Come First Serve)*
        - 98 -> 183 -> 37 -> 122 -> 14 -> 124 -> 65 -> 67
    - *Elevator (SCAN or C-SCAN)*
        - *SCAN*: 맨 앞으로 가면서 훑고 다시 순차로 가는 방식
            - 37 -> 14 -> 65 -> 67 -> 98 -> 122 -> 124 -> 183
        - *C-SCAN*: 현 위치부터 뒤로 쭉 가서 앞으로 나오는 원형 방식
            - 655 -> 67 -> 98 -> 122 -> 124 -> 183 -> 14 -> 37
    - *SPTF (Shortest Positioning Time First)*
        - track과 sector를 고려하여 가장 가까운 것을 먼저 처리
        - 현대 드라이브는 seek과 rotation 비용이 거의 동일하다.
        - 아래 그림에서 rotation이 중요하면 8을 먼저 접근함 (디스크의 하드웨어 특성에 따라 달라짐)

#img("image-17", width: 70%)

= 21-Assignment 2: KURock 
= 22-Files and Directions
== Abstractions for Storage
- 파일
    - bytes의 선형 배열
    - 각 파일은 low-level 이름을 가지고 있음 (`inode`)
    - OS는 파일의 구조에 대해 별로 알지 못함 (그 파일이 사진인지, 텍스트인지, C인지)
- 디렉토리
    - (user-readable name, low-level name)쌍의 리스트를 포함한다.
    - 디렉토리 또한 low-level 이름을 가지고 있음 (`inode`)
#img("image-18")
== Interface
=== Creating
- `O_CREAT`를 같이 사용한 `open()` system call

    #prompt(```c int fd = open("foo", O_CREAT|O_WRONLY|O_TRUNC, S_IRUSR|S_IWUSR);```)
    - `O_CREAT`: 파일이 없으면 생성
    - `O_WRONLY`: 쓰기 전용
    - `O_TRUNC`: 파일이 이미 존재하면 비우기
    - `S_IRUSR | S_IWUSR`: 파일 권한 (user에 대한 읽기, 쓰기 권한)

- File descriptor
    - An integer
        - 파일을 읽거나 쓰기 위해 file descriptor 사용(그 작업을 할 수 있는 권한이 있다고 가정)
        - 파일 형식 객체를 가리키는 포인터라고 생각할 수 있음
    - 각 프로세스끼리 독립적이다. (private하다)
        - 각 프로세스는 file descriptors의 리스트를 유지함 (각각은 system-wide하게 열린 파일 테이블에 있는 항목을 가리킨다)

=== Accessing
==== Sequential
#prompt(```bash
prompt> echo hello > foo
prompt> cat foo
hello
prompt>
```)

#prompt(```bash
prompt> strace cat foo
...
open("foo", O_RDONLY|O_LARGEFILE) = 3
read(3, "hello\n", 4096) = 6
write(1, "hello\n", 6) = 6
hello
read(3, "", 4096) = 0
close(3) = 0
...
prompt> 
```)

- `strace`는 프로그램이 실행되는 동안 만드는 모든 system call 을 추적한다. 그리고 그 결과를 화면에 보여준다.
- file descriptors 0, 1, 2는 각각 stdin, stdout, stderr를 가리킨다.
==== Random
- OS는 "현재" offset을 추적한다.
    - 다음 읽기 또는 쓰기가 어디서 시작할지는 파일을 읽고 있는 혹은 쓰고 있는 것이 결정한다.
- 암묵적인 업데이트 
    - 해당 위치에서 $N$바이트를 읽거나 쓰면 현재 offset에 $N$만큼 추가된다.
- 명시적인 업데이트
    - `off_t lseek(int fd, off_t offset, int whence);`
        - `whence`
            - `SEEK_SET`: 파일의 시작부터
            - `SEEK_CUR`: 현재 위치부터
            - `SEEK_END`: 파일의 끝부터
    - 임의로 offset의 위치를 변경할 수 있다.
==== Open File Table
- 시스템에서 현재 열린 모든 파일을 보여준다.
    - 테이블의 각 항목은 descriptor가 참조하는 기본 파일, 현재 offset 및 파일 권한과 같은 기타 관련 정보를 추적한다.
- 파일은 기본적으로 open 파일 테이블에 고유한 항목을 가지고 있다.
    - 다른 프로세스가 동시에 동일한 파일을 읽는 경우에도 각 프로세스는 open 파일 테이블에 자체적인 항목을 갖는다.
    - 파일의 논리적 읽기 또는 쓰기는 각각 독립적이다.
==== Shared File Entries
- `fork()`로 file entry 공유
#prompt(```c
int main(int argc, char *argv[]) {
    int fd = open("file.txt", O_RDONLY);
    assert(fd >= 0);
    int rc = fork();
    if (rc == 0) {
        rc = lseek(fd, 10, SEEK_SET);
        printf(“C: offset % d\n", rc);
    }
    else if (rc > 0) {
        (void)wait(NULL);
        printf(“P: offset % d\n", (int) lseek(fd, 0, SEEK_CUR));
    }
    return 0;
}
```)

#prompt(```bash
prompt> ./fork-seek
child: offset 10
parent: offset 10
prompt>
```)

#img("image-19")

- `dup()`으로 file entry 공유
    - `dup()`은 프로세스가 기존 descriptor와 동일한 open file을 참조하는 새 file descriptor를 생성한다.
        - 새 file descriptor에 대해 가장 작은 사용되지 않는 file descriptor를 사용해 file descriptor의 복사본을 만든다.
    - output redirection에 유용함

        #prompt(```bash
        int fd = open(“output.txt", O_APPEND|O_WRONLY);
            close(1);
        dup(fd); //duplicate fd to file descriptor 1
        printf(“My message\n");
        ```)
    - `dup2()`, `dup3()`

==== Writing Immediately
- `write()`
    - 파일 시스템은 한동안 쓰기 작업을 하는 것을 버퍼에 집어넣고, 나중에 특정 시점에 쓰기가 디스크에 실제로 실행된다. 
- `fsync()`
    - 파일 시스템이 모든 dirty 데이터(아직 쓰이지 않은)를 강제로 디스크에 쓴다.

=== Removing
- `unlink()`
=== Functions
- `mkdir()`
    - 디렉토리를 생성할 때, 빈 디렉토리를 생성한다.
    - 기본 항목
        - `.`: 현재 디렉토리
        - `..`: 상위 디렉토리
        - `ls -a`로 확인하면 위 2개가 나옴
- `opendir()`, `readdir()`, `closedir()`
    
    #prompt(```c
    int main(int argc, char *argv[]) {
        DIR *dp = opendir(".");
        struct dirent *d;
        while ((d = readdir(dp)) != NULL) {
            printf("%lu %s\n", (unsigned long)d->d_ino, d->d_name);
        }
        closedir(dp);
        return 0;
    }
    ```)

    #prompt(```c 
    struct dirent {
        char d_name[256]; // filename
        ino_t d_ino; // inode number
        off_t d_off; // offset to the next dirent
        unsigned short d_reclen; // length of this record
        unsigned char d_type; // type of file
    };
    ```)
- `rmdir()`
    - 빈 디렉토리를 삭제한다.
        - 빈 디렉토리가 아니면 삭제되지 않는다.
- `ln` command, `link()` system call (Hard Links)

    #prompt(```bash
    prompt> echo hello > file
    prompt> cat file
    hello
    prompt> ln file file2
    prompt> cat file2
    hello
    prompt> ls -i file file2
    67158084 file
    67158084 file2
    prompt>
    ```)
    - 디렉토리에 다른 이름을 생성하고 그것이 원본 파일의 같은 `inode`를 가리키게 한다.

- `rm` command, `unlink()` system call 

    #prompt(```bash
    prompt> rm file
    removed ‘file’
    prompt> cat file2
    hello
    ```)
    - user-readable name와 inode number 사이의 link를 제거한다.
    - reference count를 감소시키고 0이 되면 파일이 삭제된다.

== Mechanisms for Resource Sharing
- 프로세스의 추상화 
    - CPU 가상화 -> private CPU 
    - 메모리 가상화 -> private memory
- 파일 시스템 
    - 디스크 가상화 -> 파일과 디렉토리 
    - 파일들은 일반적으로 다른 유저 및 프로세스와 공유되므로 private하지 않다. 
    - Permission bits 

=== Permission Bits 
#prompt(```bash
prompt> ls -l foo.txt
-rw-r--r-- 1 remzi wheel 0 Aug 24 16:29 foo.txt
```)
- 파일의 타입 
    - `-`: 일반 파일
    - `d`: 디렉토리
    - `l`: symbolic link
- Permission bits
    - owner, group, other 순서로 읽기, 쓰기, 실행 권한을 나타낸다.
    - `r`: 읽기
    - `w`: 쓰기
    - `x`: 실행
    - 디렉토리의 경우 `x` 권한을 주면 사용자가 디렉토리 변경(`cd`)로 특정 디렉토리로 이동할 수 있다.
=== Making a File System
- `mkfs` command 
    - 해당 디스크 파티션에 루트 디렉토리부터 시작하여 빈 파일 시스템을 만든다.
    #prompt(```bash mkfs.ext4 /dev/sda1```)
    - 균일한 파일 시스템 트리 내에서 접근 가능해야 한다.

=== Mounting a File System
- `mount` command 
    - 기존 디렉토리를 대상 마운트 지점으로 사용하고, 기본적으로 해당 지점의 디렉토리 트리에 새로운 파일 시스템을 연결한다.
    #prompt(```bash mount -t ext4 /dev/sda1 /home/users```)
    - 경로 `/home/users`는 이제 새롭게 마운트된 파일 시스템의 루트를 가리킨다.