# Address Spaces (1)
## 초기 시스템
- 추상화를 많이 제공하지 않음
    - 현재 물리 메모리에 실행 중인 프로그램이 하나 있음
    - `Physical Memory`
        - `Operating System`    : 0KB ~ 64KB
        - `Current Program`     : 64KB ~ MAX 

## Multiprogramming and Time Sharing
- `Physical Memory`
    |프로세스|범위|
    |:-:|:-:|
    |Operating System|0KB ~ 64KB|
    |(free)          |64KB ~ 128KB|
    |Process C       |128KB ~ 192KB|
    |Process B       |192KB ~ 256KB|
    |(free)          |256KB ~ 320KB|
    |Process A       |320KB ~ 384KB|
    |(free)          |384KB ~ 448KB|
    |(free)          |448KB ~ 512KB|

`Multiprogramming`
- 특정 시간에 여러 프로세스들이 `ready to run`이고 OS는 이들을 switch함
- CPU의 효율적인 사용을 증가시킴

`Time Sharing`
- machine의 `crude(조잡)`한 공유: 메모리의 전체 내용을 디스크에 저장하는 것은 비용이 많이 듦 ([초기 시스템](#초기-시스템))
- 프로세스 간에 전환하면서 프로세스를 메모리에 남김

`Protection issue`
- 프로세스는 다른 프로세스의 메모리를 읽거나 쓸 수 없음

## Address Space
- 물리 메모리의 추상화를 사용하기 쉬움
- 시스템에서 메모리의 프로그램의 view를 실행
    - 실행 중인 프로그램의 모든 메모리 상태를 포함
    - 코드, 스택과 힙
- 예시
    - 64KB address space가 0에서 시작함
    - 프로그램이 실제로 물리 메모리가 0부터 64KB에 있는 것은 아님
        |프로그램|범위|
        |:-:|:-:|
        |Program Code|0KB ~ 20KB|
        |Heap|20KB ~ 40KB|
        |(free)|40KB ~ 44KB|
        |Stack|44KB ~ 64KB|

## 어떻게 메모리를 가상화할까?
- OS는 어떻게 하나의 물리 메모리 위에 여러 개의 실행 중인 프로세스를 위한 private하고 잠재적으로 큰 address space를 만들 수 있을까?

## Virtual Memory
- 실행 중인 프로그램은 특정 주소(0)의 메모리에 불러와지고 잠재적으로 매우 큰 address space($2^{32}$ bytes 또는 $2^{64}$ bytes)를 가진다고 생각하자
    - `Transparency`
        - 프로그램이 자신의 private한 물리 메모리를 가지고 있는 것처럼 작동
    - `Efficiency`
        - 시간: 프로그램을 훨씬 느리게 실행되도록 하지 않음
        - 공간: 가상화를 지원하는 데 필요한 구조에 메모리를 너무 많이 사용하지 않음
    - `Protection`
        - 프로세스간의 `Isolation(고립)`
        - OS는 서로 간에 프로세스를 보호하고 OS 자체도 프로세스로부터 보호해야 함

## Virtual Address
```C
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char *argv[]) {
    printf("location of code : %p\n", (void *)main);
    printf("location of heap : %p\n", (void *)malloc(1));
    int x = 3;
    printf("location of stack : %p\n", (void *)&x);
    return x;
}
```
```
location of code : 0x1095afe50
location of heap : 0x1096008c0
location of stack : 0x7fff691aea64
```

## 메모리의 종류
`Stack`
- 할당과 할당 해제는 컴파일러에 의해 암묵적으로 관리됨
- 때때로 `automatic memory`라고도 함

`Heap`
- 할당과 할당 해제는 프로그래머에 의해 명시적으로 관리됨
- Live beyond the call invocation
- 사용자와 시스템 모두에게 더 많은 과제를 제시함

## Memory API
- `void *malloc(size_t size)`
    - library call임 (system call이 아님)
    - 더 많은 메모리를 요청하기 위해 OS를 호출하는 일부 system call을 기반으로 구축됨
        - `brk(void *address)` : 프로그램의 break 위치 변경 (heap의 끝의 위치)
        - `sbrk(void *address)` : 이전 세그먼트에서 더해서 반환
- `void free(void *ptr)`

### 일반적인 에러들
- 메모리 할당을 잊음
    - `Segmentation fault`
```C
char *src = “hello”;
char *dst;          //oops! unallocated
strcpy(dst, src);   //segfault and die
```
```C
char *src = “hello”;
char *dst = (char *)malloc(strlen(src) + 1 );
strcpy(dst, src);   //work properly
```
- 충분한 메모리를 할당하지 않음
    - `Buffer overflow`
```C
char *src = “hello”;
char *dst = (char *)malloc(strlen(src));    //too small!
strcpy(dst, src);                           //work properly
```
- 할당된 메모리를 초기화하는 것을 잊음
- 할당된 메모리를 해제하는 것을 잊음
    - `Memory leak(메모리 부족)`
- 이미 해제된 메모리를 사용하려고 함
    - `Dangling pointer(허상 포인터)`
- 이미 해제된 메모리를 해제하려고 함
    - `Double free`
- free()를 부정확하게 호출함
    - `Invalid free`

# Address Spaces (2)
## Address Spaces
- `Address Space`
    - 프로그램 자체의 코드와 데이터가 존재하는 private한 메모리를 가지고 있다는 아름다운 환상
- `Ugly physical truth`
    - 많은 프로그램들이 실제로 동시에 메모리를 공유하고 있음
    - CPU가 한 프로그램과 다음 프로그램을 실행하는 것 사이에서 전환함

## Address Translation
- `Address Translation`
    - 명령어에 의해 제공된 virtual address가 원하는 정보가 실제로 위치한 물리적 주소로 변경
        - Fetch, Load, Store
- 예시
```C
void func() {
    int x = 3000;
    x = x + 3;
    …
}
```
```x86asm
128: movl 0x0(%ebx), %eax
132: addl $0x03, %eax
135: movl %eax, 0x0(%ebx)
```
```plaintext
Fetch the instruction at address 128
Execute this instruction (load from address 15KB)
Fetch the instruction at address 132
Execute this instruction (no memory reference)
Fetch the instruction at address 135
Execute this instruction (store to address 15KB)
```

## Hardware-based Address Translation
- 각각의 모든 메모리 참조에서 주소 변환은 하드웨어에 의해 수행됨
    - 하드웨어 혼자서는 메모리 가상화를 할 수 없음
        - OS가 하드웨어를 설정하기 위한 주요 지점에 참여해야 함
- 어떻게 메모리 가상화를 효율적이고 유연하게 할까?
    - 어플리케이션이 요구에 따라 유연하게 제공
        - 원하는 방식으로 프로그램의 address space를 사용할 수 있어야 함
    - 어플리케이션이 접근 가능한 메모리 위치에 대한 제어를 유지하려면 어떻게 해야 할까?
        - 어떤 어플리케이션도 자신의 메모리 이외의 메모리에 접근 할 수 없도록 해야 함
    - 어떻게 효율적인 매모리의 가상화를 구축할 수 있을까?

## 간단한 메모리 가상화를 위한 가정
- 유저의 address space는 반드시 물리 메모리에 연속적으로 있어야 함
- address space의 크기가 매우 크지 않아야 함
    - 물리 메모리의 크기보다 작아야 함
- 각 address space는 정확히 같은 크기여야 함

## 메모리 재배치
||address space|physical memory|
|:-:|:-:|:-:|
|Operating System||0KB ~ 16KB|
|(not in use)||16KB ~ 32KB|
|Program Code|0KB ~ 2KB|32KB ~ 34KB|
|Heap|2KB ~ 4KB|34KB ~ 36KB|
|(free)|4KB ~ 14KB|36KB ~ 46KB|
|Stack|14KB ~ 16KB|46KB ~ 48KB|
|(not in use)||48KB ~ 64KB|

## Dynamic (Hardware-based) Relocation
`Base and bounding`
- base과 bounds 레지스터
    - `base` : address space를 물리 메모리의 어느 곳에나 배치할 수 있음 (시작 지점)
    - `bounds` : 프로세스가 자신의 address space에만 접근할 수 있다는 것을 보장함 (끝 지점)

`Address translation`
- `physical address = base + virtual address`
- 예시
    ```x86asm
    128: movl 0x0(%ebx), %eax
    PC: 128B -> 32KB(32768B) + 128B = 32896B
    x: 15KB -> 32KB + 15KB = 47KB
    ```
- dynamic함
    - relocation은 runtime에 일어나고 심지어 프로세스가 실행된 후에도 변경될 수 있음

`Protection`
- 메모리 참조가 `bounds`안에 있는지 체크
- 만약 virtual address가 bounds보다 크거나 음수라면, CPU는 exception을 발생시킴
- 예시
    - `bounds` : 16KB or 48KB

## Hardware Support
|Hardware Requirements|설명|
|:-|:-|
|Privileged mode|user-mode 프로세스가 previleged operation을 실행하지 못하도록 하기 위해 필요함|
|base/bounds registers|주소 변환 및 bounds 체크를 위해 CPU마다 레지스터 쌍이 필요함|
|Ability to translate virtual addresses and check if within bounds|translation 및 제한 확인 회로(이 경우는 매우 간단함)|
|Privileged instruction(s) to update base/bounds|OS는 유저 프로그램을 실행하기 전에 이러한 값을 설정할 수 있어야 함|
|Privileged instruction(s) to register exception handlers|OS는 예외가 발생할 경우 실행할 코드를 하드웨어에 알려줄 수 있어야 함|
|Ability to raise exceptions|프로세스가 권한이 필요한 명령어나 Out-of-Bounds 메모리에 접근하려고 할 때|

## Operating System 이슈
|OS Requirements|설명|
|:-|:-|
|Memory management|- 새로운 프로세스에 매모리 할당이 필요함<br>- 종료된 프로세스로부터 메모리를 가져와야 함<br>- 일반적으로 `free list`를 통해 메모리를 관리함 _*)_|
|base/bounds management|context switch 또는 프로세스의 address space 이동 시 base/bounds를 올바르게 설정해야 함|
|Exception handling|- 예외 발생 시 실행할 코드가 필요함<br>- 가능한 조치는 프로세스를 종료하는 것|

*) 가변 크기의 address space와 물리 메모리 크기보다 큰 address space는 처리하기가 더 어려움