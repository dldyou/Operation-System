# CPU Scheduling (1)
## Workload Assumptions
- 각 작업은 동일한 시간만큼 실행됨
- 모든 작업은 동시에 도착함
- 한 번 시작된 작업은 중간에 중단되지 않음
- 모든 작업은 CPU만 사용함 (I/O 작업은 없음)
- `run-time`은 알려져 있음
<br><br>
- 비현실적이지만, 하나하나 지워가면 볼 것임

### Scheduling Metrics
`Turnaround time`
- 작업이 도착한 시간부터 완료될 때까지 걸리는 시간
    - $T_{turnaround} = T_{completion} - T_{arrival}$

### First In, First Out (FIFO)
- = First Come, First Serve (FCFS)
- 간단하고 쉬운 구현

#### Example
- 실행 시간이 다음과 같은 작업들이 동시에 도착함
    - $P_1$: 10ms
    - $P_2$: 10ms
    - $P_3$: 10ms
- $P_1, P_2, P_3$ 순으로 실행
    - Averge Turnaround Time: $\frac{10 + 20 + 30}{3} = 20$

## Workload Assumptions
- ~~각 작업은 동일한 시간만큼 실행됨~~
- 모든 작업은 동시에 도착함
- 한 번 시작된 작업은 중간에 중단되지 않음
- 모든 작업은 CPU만 사용함 (I/O 작업은 없음)
- `run-time`은 알려져 있음

### First In, First Out (FIFO)
#### Example
- 실행 시간이 다음과 같은 작업들이 동시에 도착함
    - $P_1$: 100ms
    - $P_2$: 10ms
    - $P_3$: 10ms
- $P_1, P_2, P_3$ 순으로 실행
    - Averge Turnaround Time: $\frac{100 + 110 + 120}{3} = 110$
- 지금 FIFO의 문제점이 드러남
    - $P_2, P_3$는 $P_1$이 끝날 때까지 기다려야 함
    - Convoy effect

### Shortest Job First (SJF)
- 짧은 실행 시간을 가진 작업부터 실행

#### Example
- 실행 시간이 다음과 같은 작업들이 동시에 도착함
    - $P_1$: 100ms
    - $P_2$: 10ms
    - $P_3$: 10ms
- $P_2, P_3, P_1$ 순으로 실행
    - Averge Turnaround Time: $\frac{10 + 20 + 120}{3} = 50$
    - 모든 작업이 동시에 도착할 때, 최적의 방식

## Workload Assumptions
- ~~각 작업은 동일한 시간만큼 실행됨~~
- ~~모든 작업은 동시에 도착함~~
- 한 번 시작된 작업은 중간에 중단되지 않음
- 모든 작업은 CPU만 사용함 (I/O 작업은 없음)
- `run-time`은 알려져 있음

### Shortest Job First (SJF)
#### Example
- 실행 시간과 도착 시간이 다음과 같은 작업들이 도착함 (실행 시간 / 도착 시간)
    - $P_1$: 100ms  / 0ms
    - $P_2$: 10ms   / 10ms
    - $P_3$: 10ms   / 10ms
- $P_1, P_2, P_3$ 순으로 실행
    - Averge Turnaround Time: $\frac{100 + (110 - 10) + (120 - 10)}{3} = 103.33$

# CPU Scheduling (2)
## Workload Assumptions
- ~~각 작업은 동일한 시간만큼 실행됨~~
- ~~모든 작업은 동시에 도착함~~
- ~~한 번 시작된 작업은 중간에 중단되지 않음~~
- 모든 작업은 CPU만 사용함 (I/O 작업은 없음)
- `run-time`은 알려져 있음

### Preemptive Scheduling (선점형 스케줄링)
`Non-preemptive Scheduling`
- 새로운 작업 실행 여부를 고려하기 전에 각 작업을 완료할 때까지 실행한다
- 옛날 방식의 Batch computing
- `FIFO`, `SJF`

`Preemptive Scheduling`
- 각 작업이 완료되기 전에 다른 작업을 실행할 수 있다
- Context switch
- `STCF`, `RR`

### Shortest Time-to-Completion First (STCF)
- = Preemptive SJF (PSJF)
- 남은 실행 시간이 가장 짧은 작업부터 실행

#### Example
- 실행 시간과 도착 시간이 다음과 같은 작업들이 도착함 (실행 시간 / 도착 시간)
    - $P_1$: 100ms  / 0ms
    - $P_2$: 10ms   / 10ms
    - $P_3$: 10ms   / 10ms
- $P_1, P_2, P_3, P_1$ 순으로 실행
    - 0 ~ 10ms : $P_1$
    - 10 ~ 20ms : $P_2$
    - 20 ~ 30ms : $P_3$
    - 30 ~ 130ms : $P_1$
    - Averge Turnaround Time: $\frac{120 + (20 - 10) + (30 - 10)}{3} = 50$

### Scheduling Metrics
`Turnaround time`
- 작업이 도착한 시간부터 완료될 때까지 걸리는 시간
    - $T_{turnaround} = T_{completion} - T_{arrival}$

`Response time`
- 작업이 처음으로 실행될 때까지 걸리는 시간
    - $T_{response} = T_{first run} - T_{arrival}$

### Shortest Time-to-Completion First (STCF)
#### Example
- 실행 시간과 도착 시간이 다음과 같은 작업들이 도착함 (실행 시간 / 도착 시간)
    - $P_1$: 100ms  / 0ms
    - $P_2$: 10ms   / 10ms
    - $P_3$: 10ms   / 10ms
- $P_1, P_2, P_3, P_1$ 순으로 실행
    - 0 ~ 10ms : $P_1$
    - 10 ~ 20ms : $P_2$
    - 20 ~ 30ms : $P_3$
    - 30 ~ 130ms : $P_1$
    - Averge Turnaround Time: $\frac{120 + (20 - 10) + (30 - 10)}{3} = 50$
    - Averge Response Time: $\frac{0 + 0 + 10}{3} = 3.33$
<br><br>
- turnaround time이 좋지만, response time과 interactivity가 안 좋음

### Round Robin (RR)
- = Time Slicing
- 각 작업이 동일한 시간(`time slice`)만큼 실행 (`time quantum`)

#### Example
- 실행 시간과 도착 시간이 다음과 같은 작업들이 도착함 (실행 시간 / 도착 시간)
    - $P_1$: 10ms  / 0ms
    - $P_2$: 10ms   / 0ms
    - $P_3$: 10ms   / 0ms
- time slice: 2ms
    - 0 ~ 2ms : $P_1$
    - 2 ~ 4ms : $P_2$
    - 4 ~ 6ms : $P_3$
    - 6 ~ 8ms : $P_1$
    ...
    - Averge Turnaround Time: $\frac{26 + 28 + 30}{3} = 28$
    - Averge Response Time: $\frac{0 + 2 + 4}{3} = 2$
        - response time과 context switching의 비용 간의 균형을 고려해야 함

## Workload Assumptions
- ~~각 작업은 동일한 시간만큼 실행됨~~
- ~~모든 작업은 동시에 도착함~~
- ~~한 번 시작된 작업은 중간에 중단되지 않음~~
- ~~모든 작업은 CPU만 사용함 (I/O 작업은 없음)~~
- `run-time`은 알려져 있음

### Incorporating I/O
- 작업이 I/O 요청을 할 때, 스케줄러가 결정
    - 작업은 I/O 작업이 끝날 때까지 blocked wating 상태
    - 스케줄러는 I/O 작업이 끝날 때에도 누구에게 할당할지 결정함
    - I/O 하느라 DISK를 사용하는 동안 다른 작업이 CPU 사용

## Workload Assumptions
- ~~각 작업은 동일한 시간만큼 실행됨~~
- ~~모든 작업은 동시에 도착함~~
- ~~한 번 시작된 작업은 중간에 중단되지 않음~~
- ~~모든 작업은 CPU만 사용함 (I/O 작업은 없음)~~
- ~~`run-time`은 알려져 있음~~
<br><br>
- 이러한 선행 조건 없이 SJF / STCF와 같은 접근 방식을 사용할 수 있을까?