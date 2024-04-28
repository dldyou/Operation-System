# Paging (1)
## Sagementation 문제점
- 메모리 조각이 가변적임
- External fragment가 존재하게 됨

## Paging
- frame이라고 불리는 고정된 크기의 슬롯으로 물리 메모리를 쪼갬
- 힙과 스택의 direction 정보가 필요하지 않음
- free-space 관리가 간단함

### 예시
- virtual address space
    - 00~16: virtual page 0
    - 16~32: virtual page 1
    - 32~48: virtual page 2
    - 48~64: virtual page 3
- physical memory
    - 00~16: page frame 0 (OS)
    - 16~32: page frame 1
    - 32~48: page frame 2
    - 48~64: page frame 3
    - ...

### Address Translation
`Page table`
- 아래의 정보를 저장하는 자료 구조
    - VP 0 -> PF 3
    - VP 1 -> PF 7
    - VP 2 -> PF 5
    - VP 3 -> PF 2

`Virtual address`
- Virtual page number + offset
- 6-bit addressing (64-byte address sapce)
    |Va5|Va4|Va3|Va2|Va1|Va0|
    |---|---|---|---|---|---|
- page size: 16 bytes
    - Va5 Va4 : VPN (Virtual page number)
    - Va3 Va2 Va1 Va0 : offset

#### 예시: address 21

||VPN|offset|
|:--|--:|:-:|
|virtual address       |  01|0101|
|address translation   | XXX|    |
|physical address      | 111|0101|
|                      |**PFN**|**offset**|

## 가질 수 있는 질문
- table이 얼마나 커야 하는지
- page table이 어디에 저장되는지
- page table에 어떤 내용이 있는지
- paging이 시스템을 너무 느리게 하지는 않는지

### table이 얼마나 커야 하는지
- page table은 굉장히 클 수 있다
    - 32-bit address space는 4KB page를 가짐
        - 20-bit VPN / 12-bit offset (4KB)
        - $2^{20}$ 개의 entires가 각 프로세스마다 존재
            - 각 엔트리는 PFN과 다른 속성값들이 더해진 32 bit 크기의 PTE (Page Table Entry)임
            - $2^{20}\times 32$ b = $4$ MB
        - 각 page table마다 4MB의 메모리가 필요함

### page table이 어디에 저장되는지
- 레지스터로 관리하기에는 4MB는 너무 큼
    - CPU가 아닌 메모리에 존재, OS가 이걸 관리
        - OS는 CPU가 정해놓은 포맷에 따라 진행

### page table에 어떤 내용이 있는지
`Page table`
- VPN -> PFN을 매핑하는 것이 중요
- `Linear page table`
    - VPN은 index로 처리 -> PFN
    - 다른 기타 정보들 

`PTE`
- `Valid bit`
    - 현재 매핑이 유효한지 (여태까지 접근한 적이 있는지)
    - address space에 대한 모든 virtual page에 대해 모두가 매핑될 필요는 없다는 것을 의미함
- `Protection bits`
    - 해당 페이지가 readable, writable, executable인지...
- `Present bit`
    - 해당 페이지가 물리 메모리(또는 디스크)에 있는지
- `Dirty bit`
    - 매핑되고 나서 무언가가 써진 상태 (업데이트 된 상태)
- `Reference bit`
    - 프로세스가 실행하면서 프로세스가 접근을 했는지
    - page replacement 정책에 의해 사용됨

- 예시: x86-32 PTE
    - P: present bit
    - R/W: read/write bit
    - U/S: user/supervisor bit
    - A: accessed bit
    - D: dirty bit
    - PWT, PCD, PAT, G: 하드웨어 캐싱 정책
    - 사용되지 않는 9~11 bit: 나중에 무언가 새로운게 추가되면 여기에 추가됨
    - PFN

### paging이 시스템을 너무 느리게 하지는 않는지
`Page-table base register`
- 하드웨어는 현재 실행 중인 프로세스의 page table이 어디인지를 가리켜야 함
<br><br>
- Address translation
    ```C
    VPN = (VirtualAddress & VPN_MASK) >> SHIFT
    PTEAddr = PTBR + (VPN * sizeof(PTE))
    ```
    - 6-bit addressing (64-byte address space)
        - VPN_MASK: 0x30 (110000)
        - SHIFT: 4
    ```C
    PTE = AccessMemory(PTEAddr)
    if (PTE.Valid == False)
        RaiseException(SEGMENTATION_FAULT)
    else if (CanAccess(PTE.ProtectBits) == False)
        RaiseException(PROTECTION_FAULT)
    else
        offset = VirtualAddress & OFFSET_MASK
        PhysAddr = (PTE.PFN << SHIFT) | offset
        Register = AccessMemory(PhysAddr) 
    ```