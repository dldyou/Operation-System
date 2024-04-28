# Segmentation (1)
## Base and Bounding
- base and bounds 레지스터
- **"free"** space의 큰 청크 (스택과 힙 사이의 공간)
    - 전체 address space를 물리 메모리 어딘가에 재배치할 때, 무리적 메모리를 차지함
    - 전체 address space가 메모리에 맞지 않을 때 프로그램을 실행하기 어려움

## 큰 address space를 어떻게 지원할까?
- 32bit 체제에서 한 프로세스를 위한 address space는 4GB임
    - 4GB의 연속적인 메모리를 할당하려고 하면 공간이 몇 개의 프로세스만 지원 가능함

## Segmentation
`Segment`
- 특정 길이의 address space에서 연속적인 부분
    - 코드, 스택, 힙
- 각각은 base와 bounds 쌍을 가지고 있음

`Segmentation`
- 각 세그먼트는 물리 메모리에서 연속적이거나 순서대로 있을 필요가 없음
- virtual address space가 사용되지 않는 물리 메모리는 채우지 않음
    - 사용하는 메모리에 대해서만 물리 메모리에 할당됨
    - address space가 크더라도 효율적으로 배치할 수 있음

### Example: Relocation
#### 이전 방식
|                          |Physical Memory|
|:------------------------:|:-------------:|
|Operating System          |0KB ~ 16KB     |
|(not in use)              |16KB ~ 32KB    |
|Program Code              |32KB ~ 34KB    |
|Heap                      |34KB ~ 36KB    |
|(allocated but not in use)|36KB ~ 46KB    |
|Stack                     |46KB ~ 48KB    |
|(not in use)              |48KB ~ 64KB    |
#### Segmentation
||Physical Memory|
|:-:|:-:|
|Operating System|0KB ~ 16KB|
|(not in use)|16KB ~ 28KB|
|Stack|28KB ~ 30KB|
|(not in use)|30KB ~ 32KB|
|Program Code|32KB ~ 34KB|
|Heap|34KB ~ 36KB|
|(not in use)|36KB ~ 48KB|

- Segment Registers

|Segment|Base|Size|
|-------|----|----|
|Code   |32K |2K  |
|Heap   |34K |2K  |
|Stack  |28K |2K  |
### Example: Address Translation
- Segmentation에서 코드와 힙이 붙어 있었는데 address space에서는 떨어져 있다고 가정 (14-bit addressing에서 offset에 따르면 각 세그먼트의 크기는 4KB까지 가능함)

|            |Address Space|
|:----------:|:-----------:|
|Program Code|0KB ~ 2KB    |
|(free)      |2KB ~ 4KB    |
|Heap        |4KB ~ 6KB    |
|(free)      |6KB ~ 14KB   |
|Stack       |14KB ~ 16KB  |
- 100, 4200, 7KB를 접근하려고 함
- 100번지 접근
    - `Fetch from address 100`
        - 32KB + 100 = 32868
        - 100은 2KB보다 작음
- 4200번지 접근
    - `Load from address 4200`
        - 34KB + 4200 = 39016B (x)
        - offset = 4200 - 4KB (address space에서의 base) = 104
        - 34KB + 104 = 34920B (o)
        - 104는 2KB보다 작음
- 7KB 접근
    - `Load from address 7KB`
        - 정해놓은 세그먼트 밖에 존재, Segmentation violation 또는 Segmentation fault 발생

# Segmentation (2)
## 어떤 세그먼트에 속한지를 아는 방법
- 명확한 방법
    - 예시: 14-bit addressing (16KB address space)
    - 상위 2bit는 Segment
        - `00`: 코드
        - `01`: 힙
        - `11`: 스택
        - `10`은 사용하지 않음
    - 하위 12bit는 Offset
        - 각 세그먼트의 크기: $2^{12}$ b = $4$ KB
- address translation (하드웨어에 의해 작동, CPU)

```C
// get top 2 bits of 14-bit VA
Segment = (VirtualAddress & SEG_MASK) >> SEG_SHIFT
// now get offset
Offset = VirtualAddress & OFFSET_MASK
if (Offset >= Bounds[Segment])
    RaiseException(PROTECTION_FAULT)
else
    PhysAddr = Base[Segment] + Offset
    Register = AccessMemory(PhysAddr) 
```
- SEG_MASK: 0x3000 -> 상위 2비트만 11, 나머지 0
- SEG_SHIFT: 12
- OFFSET_MASK 0xFFF

## 스택 세그먼트에서는?
- 코드나 힙은 아래로 자라는데, 스택은 위로 자람
    - 이에 대한 정보가 있어야 함

|Segment|Base|Size|Grows Positive?|
|-------|----|----|---------------|
|Code   |32K |2K  |1              |
|Heap   |34K |2K  |1              |
|Stack  |28K |2K  |0              |

- 예시: virtual address 15KB 접근
    |13|12|11|10|09|08|07|06|05|04|03|02|01|00|
    |--|--|--|--|--|--|--|--|--|--|--|--|--|--|
    |1 |1 |1 |1 |0 |0 |0 |0 |0 |0 |0 |0 |0 |0 |
    - Segment: 11
    - 최대 세그먼트 크기: 4KB
    - Offset: 3KB - 4KB(최대 세그먼트 크기, grow negative) = -1KB
    - Physical address = 28KB - 1KB = 27KB
    - |-1KB|는 2KB보다 작다

## Support for Sharing
`Code sharing`
- 메모리를 아끼기 위해, 특정 메모리 세그먼트 간 address space를 공유 (read only여야만 함)
    - 코드 세그먼트
- `Protection bits`
    |Segment|Base|Size|Grows Positive?|Protection  |
    |-------|----|----|---------------|------------|
    |Code   |32K |2K  |1              |Read-Execute|
    |Heap   |34K |2K  |1              |Read-Write  |
    |Stack  |28K |2K  |0              |Read-Write  |
    - 코드 세그먼트가 read-only로 설정되면, 같은 코드는 여러 프로세스에서 공유될 수 있음

# Segmentation (3)
## Fine-grained vs. Coarse-grained
`Coarse-grained segmentation`
- 큰 덩어리로 쪼개는 것
- 코드, 스택, 힙

`Fine-grained segmentation`
- 하드웨어가 지원하는 만큼 많은 세그먼트로 쪼개는 것
- `Segment table`

## OS Support
- Context switch
    - 세그먼트 레지스터는 저장되어야 함

- 물리 메모리에서 free space를 관리
    - 새로운 addres space가 생기면 OS는 그 세그먼트의 물리 메모리에 사용 가능한 공간을 찾을 수 있어야 함
        - 각각 다른 크기를 갖는 세그먼트를 잘 배치할 수 있어야 함
    - External fragmentation
        - 공간들을 할당하고 해제하면서 사용되지 않는 작은 공간들이 분산됨 -> 이 공간들을 합쳐보면 낭비되는 공간이 꽤 큼

- `Physical memory compaction`
    ||Physical Memory||Physical Memory|
    |:-:|:-:|:-:|:-:|
    |Operating System|0KB ~ 16KB|Operating System|0KB ~ 16KB|
    |(not in use)|16KB ~ 24KB|Allocated|16KB ~|
    |Allocated|24KB ~ 32KB|Allocated||
    |(not in use)|32KB ~ 40KB|Allocated| ~ 40KB|
    |Allocated|40KB ~ 48KB|(not in use)|40KB ~|
    |(not in use)|48KB ~ 56KB|(not in use)||
    |Allocated|56KB ~ 64KB|(not in use)| ~ 64KB|
    - 24KB가 비어있으나 OS는 20KB짜리 세그먼트를 할당할 수 없음 -> 오른쪽과 같이 변경해야 함

- Free-list management 알고리즘
    - `Best-fit`: 가장 크기가 비슷한 순 (남은 공간 오름차순 정렬) - external fragmentation이 많아질 수 있음
    - `Worst-fit`: 남은 공간 내림차순 정렬 후 앞에서부터 들어갈 수 있는지 확인
    - `First-fit`: 정렬 안 하고 앞에서부터 들어갈 수 있는지 확인
    - `Buddy algorithm`: (수업에서 안 다룸) 2의 거듭제곱으로 할당