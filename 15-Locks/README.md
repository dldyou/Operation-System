# Pthread Locks
```c
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
...
pthread_mutex_lock(&lock);
counter = counter + 1; // critical section
pthread_mutex_unlock(&lock);
```
- Lock을 어떻게 설계해야 할까?
    - 하드웨어 / OS 차원에서의 지원이 필요한가?

## Evaluting Locks
- 상호 배제(Mutual Exclution)
    - 둘 이상의 스레드가 동시에 critical section에 들어가는 것을 방지
- 공평(Fairness)
    - lock을 두고 경쟁할 때, lock이 free가 되었을 때, lock을 얻는 기회가 공평함
- 성능(Performance)
    - lock을 사용함으로써 생기는 오버헤드
        - 스레드의 수
        - CPU의 수

## Controlling Interrupts
```c
void lock() {
    DisableInterrupts();
}
void unlock() {
    EnableInterrupts();
}
```
- 이러한 모델은 간단하지만 많은 단점이 있음
    - thread를 호출하는 것이 반드시 privileged operation으로 수행되어야 함
    - 멀티프로세서 환경에서 작동하지 않음
    - 인터럽트가 손실될 수 있음
- 한정된 contexts에서만 사용될 수 있음
    - 지저분한 인터럽트 처리 상황을 방지하기 위해

# Spin Locks with Loads / Stores
```c
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
```
- 상호 배제가 없음
    - thread 1에서 lock()을 호출하고 while(flag == 1)에서 1이 아니구나 하고 빠져나갈 때 context switch가 일어남
    - thread 2에서 lock()을 호출하고 while(flag == 1)에서 1이 아니구나 하고 빠져나가서 flag = 1로 만듦 
    - context switch가 일어나 thread 1이 다시 돌아와서 flag = 1이 됨
    - 두 스레드 모두 lock을 얻게 됨
- 성능 문제
    - spin-wait으로 인한 CPU 사용량이 많아짐

# Spin Locks with Test-and-Set
- Test-and-Set atomic instruction
```c
int TestAndSet(int *old_ptr, int new) {
    int old = *old_ptr; // fetch old value at old_ptr
    *old_ptr = new; // store ’new’ into old_ptr
    return old; // return the old value
} 
```
```c
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
```
- 공평하지 않음 (starvation이 발생할 수 있음)
- 단일 CPU에서 오버헤드가 굉장히 클 수 있음

# Spin Locks with Compare-and-Swap
- Compare-and-Swap atomic instruction
```c
int CompareAndSwap(int *ptr, int expected, int new) {
    int actual = *ptr;
    if (actual == expected)
        *ptr = new;
    return actual;
}
```
```c
void lock(lock_t *lock) {
    while (CompareAndSwap(&lock->flag, 0, 1) == 1);
}
```
- Test-and-Set과 동일하게 동작함

# Ticket Locks
- Fetch-and-Add atomic instruction
    - 번호표 발급으로 생각하면 됨
```c
int FetchAndAdd(int *ptr) {
    int old = *ptr;
    *ptr = old + 1;
    return old;
}
```
```c
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
```

# Hardware Support
- 간단한 방법으로는 `yield()`(본인이 ready큐로, 즉 CPU자원을 포기한다고 함)를 사용할 수 있음
    - 그러나 여전히 비용이 높고 공평하지 않음
        - RR에 의해 스케줄 된 많은 스레드가 있는 상황을 고려해보자
```c
void lock(lock_t *lock) {
    while (TestAndSet(&lock->flag, 1) == 1)
        yield();
}
``` 
- 하드웨어 만으로는 상호 배제 및 공평성만 해결 할 수 있었음
    - 성능 문제는 여전히 존재 -> OS의 도움이 필요

# OS Support
- spin을 하는 대신 sleep을 함
- Solaris
    - `park()`: 호출한 스레드를 sleep 상태로 만듦
    - `unpark(threadID)`: `threadID`의 스레드를 깨움

# Locks with Queues 
