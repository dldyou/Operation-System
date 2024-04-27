# Multi-Level Feedback Queue (1)
## Scheduling Metrics
`Turnaround time`
- 작업이 도착한 시간부터 완료될 때까지 걸리는 시간
    - $T_{turnaround} = T_{completion} - T_{arrival}$
    - OS는 일반적으로 작업이 얼마나 실행되는지 알지 못함
        - `SJF`와 `STCF`는 각 작업의 실행 시간이 알려져 있다고 가정함

`Response time`
- 작업이 처음으로 실행될 때까지 걸리는 시간
    - $T_{response} = T_{first run} - T_{arrival}$
    - OS는 사용자의 상호작용을 보다 빠르게 만들고자 함
        - `RR`는 `response time`을 줄이지만 `turnaround time`이 늘어남

## 문제의 핵심
- 어떻게 스케줄러가 `turnaround time`과 `response time`이 둘 다 좋도록 디자인할 수 있을까?
    - interactive 작업의 `response time`을 최소화
    - `turnaround time`을 최소화
    - 작업의 길이을 알지 못한채로 진행

## Multi-Level Feedback Queue (MLFQ)
- Multiple queues
    - 각 큐는 다른 우선 순위를 가짐
    - 특정 시간에 실행할 준비가 된 작업이 단일 큐에 있음
- Basic rules
    - **Rule 1**: 만약 `Priority(A) > Priority(B)`면 A가 실행됨 (B는 실행되지 않음)
    - **Rule 2**: 만약 `Priority(A) = Priority(B)`면 A와 B는 `Round Robin(RR)`으로 실행됨

### MLFQ Example (Ready Queue)
<pre>
[High Priority] Q8 -> A -> B 
                Q7 
                Q6 
                Q5 
                Q4 -> C 
                Q3 
                Q2 
                Q1 
[Low Priority]  Q0 -> D
</pre>

### 스케줄러는 우선 순위를 어떻게 정할까?
- 각 작업마다 고정된 우선 순위를 할당
- 관측한 동작에 따라 작업의 우선 순위 변경
    - MLFQ는 작업의 미래 동작을 예측하기 위해 `history`를 사용
    - 만약 작업이 CPU를 긴 시간동안 집중적으로 사용하면, MLFQ는 해당 작업의 우선 순위를 낮춤

### 우선 순위를 어떻게 바꿀까?
- Workload
    - `I/O bound 작업`
        - Interactive and short-running
    - `CPU bound 작업`
        - Compute intensive and longer-running
- 우선 순위 조정 알고리즘
    - **Rule 3**: 작업이 시스템에 들어오면, 가장 높은 우선 순위에 배치
    - **Rule 4a**: 작업이 실행되는 동안 `time slice`를 전부 사용하면, 우선 순위를 낮춤
    - **Rule 4b**: 작업이 `time slice`를 모두 사용하기 전에 CPU를 반납하면, 우선 순위를 유지함

# Multi-Level Feedback Queue (2)
## 문제점
`Starvation`
- 시스템에 너무 많은 interactive 작업이 들어오는 경우

`Gaming and scheduler`
- `time slice`를 모두 사용하기 전에 `I/O 작업`을 진행하는 경우

`Changing behaivor`
- 작업이 CPU를 사용하는 방식이 변하는 경우 (`CPU bound` -> `I/O bound`)

### Priority Boost
- 주기적으로 시스템에 있는 모든 작업의 우선 순위를 높임
    - **Rule 5**: $S$ 시간이 지나면, 모든 작업의 우선 순위를 끝까지 높임
    - `starvation`과 `changing behaivor`를 해결할 수 있음


### Better Accounting
`Gaming tolerance`
- **Rule 4**: 작업이 주어진 수준에서 시간 할당량(`time allotment`)을 모두 사용하면 우선 순위가 줄어들게 됨 (CPU를 반납한 횟수와 상관없이, 반납할 때마다 다시 time slice만큼으로 초기화가 아니고 남은 시간으로 유지됨)

### Accounting for Changes in Behavior
- `Priority Boost`
    - `starvation`과 `changes in behavior`를 해결하려면 어느 정도마다 boost를 해야할까?
        - Solaris에서는 `1초`마다 boost를 함

- 큐마다 time slice는 얼마나 커야할까?
    - 높은 우선 순위 큐들은 짧은 time slice를 가짐
        - Solaris에서는 `20ms`
    - 낮은 우선 순위 큐들은 긴 time slice를 가짐
        - Solaris에서는 `몇 백ms`