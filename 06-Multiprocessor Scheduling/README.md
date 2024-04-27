# Multi-Level Feedback Queue 정리
- **Rule 1**: 만약 `Priority(A) > Priority(B)`면 A가 실행됨 (B는 실행되지 않음)
- **Rule 2**: 만약 `Priority(A) = Priority(B)`면 A와 B는 `Round Robin(RR)`으로 실행됨
- **Rule 3**: 작업이 시스템에 들어오면, 가장 높은 우선 순위에 배치
- **Rule 4**: 작업이 실행되는 동안 시간 할당량을 전부 사용하면, 우선 순위를 낮춤
- **Rule 5**: $S$ 시간이 지나면, 모든 작업의 우선 순위를 끝(`topmost` 작업들 중 최고 우선 순위의 큐)까지 높임

# Multiprocessor Scheduling (1)

## Multicore Architecture
- CPU와 캐시 > (Core와 캐시), (Core와 캐시)... > 
- SMP는 CPU와 캐시들을 공유된 메모리 시스템으로 연결
- NUMA는 CPU와 캐시들을 독립된 메모리 시스템으로 연결

## Single-Queue Scheduling
`Single-queue multiprocessor scheduling (SQMS)`
- 단일 프로세서 스케줄링을 위해 기본 프레임워크를 재사용하는 것이 간단함
- 가장 뛰어난(`best`) $n$개의 작업을 골라서 실행시킴 ($n=$ CPU의 개수)
- 동기화 오버헤드를 위한 확장성이 떨어짐
- `Cache Affinity(캐시 친화성)`

## Multi-Queue Scheduling
`Multi-queue multiprocessor scheduling (MQMS)`
- CPU당 하나
- 작업이 시스템에 들어오면, 정확히 하나의 스케줄링 큐에만 들어감
    - Random, shorter queue 등
- 그러면 기본적으로 independent하게 스케줄링됨
    - 동기화를 피하고 `cache affinity`를 제공할 수 있음
- `Load imbalance (부하 불균형)` 해결 필요
    - `Migration`
    - `Work stealing`
        - 작업량이 적은 (source) 큐가 가끔 다른 (target) 큐에서 하나 또는 더 많은 작업을 가져감

# Multiprocessor Scheduling (2)
## Linux CPU Schedulers
`Completely Fair Scheduler (CFS)`
- `SCHED_NORMAL` (전통적으로 `SCHED_OTHER`로 불림)
- `Weighted fair scehduling (가중 공정 스케줄링)`

`Real-Time Schedulers`
- `SCHED_FIFO`와 `SCHED_RR`
- `Priority-based scheduling (우선 순위 기반 스케줄링)`
- `sched_setattr()`

`Deadline Schedulers`
- `SCHED_DEADLINE`
- `Earliest Deadline First (EDF) like periodic scheduling (최초 마감 기한 우선 주기적 스케줄링)`
- `sched_setattr()`

### Completely Fair Scheduler (CFS)
`vruntime`
- 각 task는 `virtual runtime`을 기반으로 `red-black tree`에 저장됨
- `Weighted runtime`은 각 프로세스의 `nice`값(-20 ~ 19)을 기반으로 계산됨
    - $vruntime = vruntime + DeltaExac\times \frac{Weight_0=1024}{Weight_p}$
    - `nice`값이 낮을수록 높은 우선 순위를 가짐
    - `/proc/<pid>/sched`에서 확인 가능

|Nice|$Weight_p$|$\frac{Weight_0}{Weight_p}$|
|:-:|:-:|:-:|
|-10|9548|0.107|
|-5|3121|0.328|
|0 (default)|1024 ($Weight_0$)|1|
|5|335|3.0575|
|10|110|9.309|

#### Priroity
- prio = nice + 120
    - CFS: 100 ~ 139
    - 0 ~ 99가 `real-time` 스케줄러에 예약됨
- `renice`
    - 유저는 `nice`값을 -1 ~ -20으로는 변경하지 못함
        - `root`만 가능

#### Contorl Group (cgroup)
- 동일한 응용 프로그램의 threads가 `cgroup`이라는 구조로 그룹화됨
    - cgroup은 모든 threads의 vruntime의 합에 해당하는 vruntime을 가짐
    - 그런 다음 CFS는 알고리즘을 cgroup에 적용하여 threads 그룹 간의 `fairness`를 보장함
    - cgroup이 예약 대상으로 선택되면, vruntime이 가장 낮은 thread가 실행되어 cgroup 내의 `fairness`를 보장함

#### Starvation Avoidance
- CFS는 주어진 시간 내에 모든 threads를 스케줄링하여 `thread starvation`을 피함
    - CFS는 두 threads 간의 virtual runtime 차이가 선점 시간보다 짧음을 보장함

#### 부하 분산 (Load Balancing)
- `Load metric`
    - thread의 부하: 평균 CPU 사용량 (thread의 우선 순위에 따라 가중된)
    - core의 부하: thread의 부하의 합
- core들의 부하를 균등하게 처리하기 위해 노력함
    - 4ms마다 모든 코어가 다른 코어로부터 작업을 훔치려고 함 (`work stealing`)
    - 코어들은 유휴 상태가 되면, 즉시 주기적 load balancer를 호출
    - `Topology awareness`
        - 두 코어 사이의 거리가 클수록, CFS가 부하의 균형을 맞추려면 불균형이 커져야 함
            - 예를 들어 NUMA 노드가 2개인 시스템에서 노드 간의 차이가 작으면 (실제 25% 미만) 부하 분산이 수행되지 않음

# Multiprocessor Scheduling (3)
## Diving into Linux Kernel v5.11.8
- Scheduling classes (`/kernel/sched/sched.h`)
```C
struct sched_class {
    void (*enqueue_task)   (struct rq *rq,
                            struct task_struct *p,
                            int flags);
    void (*dequeue_task)   (struct rq *rq,
                            struct task_struct *p,
                            int flags);
    ...
    struct task_struct *(*pick_next_task)(struct rq *rq);
    ...
    int (*balance) (struct rq *rq, struct task_struct *prev,
                    struct rq_flags *rf);
    ...
}
```
```C
extern const struct sched_class dl_sched_class;
extern const struct sched_class rt_sched_class;
extern const struct sched_class fair_sched_class;
extern const struct sched_class idle_sched_class;
```
- CFS scheduling class (`/kernel/sched/fair.c`)
```C
DEFINE_SCHED_CLASS(fair) = {
    .enqueue_task   = enqueue_task_fair,
    .dequeue_task   = dequeue_task_fair,
    ...
    .pick_next_task = __pick_next_task_fair,
    ...
    .balance        = balance_fair,
    ...
}
```
- Per-CPU runqueue (`/kernel/sched/sched.h`)
```C
struct rq {
    raw_spinlock_t      lock;
    ...
    struct cfs_rq       cfs;
    struct rt_rq        rt;
    struct dl_rq        dl;
    ...
    struct task_struct  *curr;
    struct task_struct  *idle;
}
```
- CPU scheduler (`/kernel/sched/core.c`)
    - `schedule()` -> `__schedule()`
```C
static void __sched notrace __schedule(bool preempt)
{
    ...
    prev    = rq->curr;
    ...
    next    = pick_next_task(rq, prev, &rf);
    ...
    rq      = context_switch(rq, prev, next, &rf);
    ...
}
```
- CPU scheduler (`/kernel/sched/core.c`)
    - `schedule()` -> `__schedule()` -> `pick_next_task()`
```C
static inline struct task_struct *
pick_next_task(struct rq *rq, struct task_struct *prev,
struct rq_flags *rf)
{
    ...
    put_prev_task_balance(rq, prev, rf);
    
    for_each_class(class) {
        p = class->pick_next_task(rq);
        if (p)
            return p;
    }
    ...
}
```