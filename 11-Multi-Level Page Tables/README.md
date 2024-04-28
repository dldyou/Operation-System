# Multi-Level Page Tables (1)
## Linear page table
- page table이 너무 커서 메모리도 많이 잡아먹음
    - 32-bit address space (4KB page, 12-bit offset)
    - 32-bit의 PTE크기 (4B)
    - page table는 4MB
- page table을 더 작게 만들면?
    - 이 자료 구조로 생기는 부작용은?

### 예시
- 16KB address space (1KB page), physical memory (32KB)
    ||virtual address space|mapping to physical memory|
    |:-:|:-:|:-:|
    |0|code|10|
    |1|||
    |2|||
    |3|||
    |4|heap|23|
    |5|||
    |6|||
    |7|||
    |8|||
    |9|||
    |10|||
    |11|||
    |12|||
    |13|||
    |14|stack|28|
    |15|stack|4|
- page table
    |PFN|valid|prot|present|dirty|
    |:-:|:---:|:--:|:-----:|:---:|
    |10 |  1  |r-x |   1   |  0  |
    | - |  0  | -  |   -   |  -  |
    | - |  0  | -  |   -   |  -  |
    | - |  0  | -  |   -   |  -  |
    |23 |  1  |rw- |   1   |  1  |
    | - |  0  | -  |   -   |  -  |
    | - |  0  | -  |   -   |  -  |
    | - |  0  | -  |   -   |  -  |
    | - |  0  | -  |   -   |  -  |
    | - |  0  | -  |   -   |  -  |
    | - |  0  | -  |   -   |  -  |
    | - |  0  | -  |   -   |  -  |
    | - |  0  | -  |   -   |  -  |
    | - |  0  | -  |   -   |  -  |
    |28 |  1  |rw- |   1   |  1  |
    | 4 |  1  |rw- |   1   |  1  |
    - valid가 0이라고 표시된 곳도 자리를 잡고 있어야 함 -> 공간의 낭비가 심함

## 간단한 접근법
- 더 큰 페이지 크기
    - 32-bit address space (16KB page, 14-bit offset)
    - page table은 1MB
- 큰 페이지의 크기는 각 페이지 내에서 낭비가 있음
    - Internal fragmentation
- 대부분의 시스템은 보통 비교적 작은 페이지 크기를 가짐
    - 4KB in x86
    - 8KB in SPARCv9
## 복합적인 접근법
- Paging과 semgent를 사용
    - 하나의 세그먼트 당 하나의 page table
    - 3개의 base/bounds 쌍 (코드, 스택, 힙)
        - 세그먼트의 base/bounds가 아니라 page table의 base/bounds를 가리키는 것
    - base 레지스터: page table의 시작
    - bounds 레지스터: valid page의 최대값
        - base와 bounds 사이에 invalid가 있을 수 있음
    - 상당한 메모리를 아낄 수 있음

### 예시
- 32-bit virtual address space (4KB pagg)
    - 4개의 세그먼트
        - `00` : 사용하지 않음
        - `01` : 코드
        - `10` : 힙
        - `11` : 스택
    - 31~30: Seg
    - 29~12: VPN
    - 11~00: Offset
    ```C
    SN = (VirtualAddress & SEG_MASK) >> SN_SHIFT
    VPN = (VirtualAddress & VPN_MASK) >> VPN_SHIFT
    AddressOfPTE = Base[SN] + (VPN * sizeof(PTE))
    ```

### 단점
- 크지만 힙처럼 여전히 낭비되는 부분이 있을 수 있음
- External fragmentation이 발생할 수 있음
# Multi-Level Page Tables (2)
`Page table`
- page 크기만큼으로 쪼개놓은 page table 덩어리
- 만약 PTE의 모든 page가 invalid하다면 page table의 모든 page를 할당하지 않음

`Page directory`
- page table을 묶어서 상위에서 관리

## Multi-Level Page Tables
- Linear Page Table
    |valid|prot|PFN|PTBR|
    |:---:|:--:|:-:|:-:|
    |  1  | rx |12 |_**PFN201**_|
    |  1  | rx |13 ||
    |  0  | -  | - ||
    |  1  | rw |100||
    |  0  | -  | - |PFN202|
    |  0  | -  | - ||
    |  0  | -  | - ||
    |  0  | -  | - ||
    |  0  | -  | - |PFN203|
    |  0  | -  | - ||
    |  0  | -  | - ||
    |  0  | -  | - ||
    |  0  | -  | - |PFN204|
    |  0  | -  | - ||
    |  1  | rw |86 ||
    |  1  | rw |15 ||

- Page Directory
    |PDBR  |valid|PFN|
    |:----:|:---:|:-:|
    |PFN200|  1  |201|
    |      |  0  | - |
    |      |  0  | - |
    |      |  1  |204|

- Page Table(PFN201 -> 201과 204만 있음)
    |valid|prot|PFN|
    |:---:|:--:|:-:|
    |  1  | rx |12 |
    |  1  | rx |13 |
    |  0  | -  | - |
    |  1  | rw |100|

### Address Translation
```C
VPN = (VirtualAddress & VPN_MASK) >> SHIFT
(Success, TlbEntry) = TLB_Lookup(VPN)
if (Success == True) // TLB Hit
    if (CanAccess(TlbEntry.ProtectBits) == True)
        Offset = VirtualAddress & OFFSET_MASK
        PhysAddr = (TlbEntry.PFN << SHIFT) | Offset
        Register = AccessMemory(PhysAddr)
    else
        RaiseException(PROTECTION_FAULT)
else // TLB Miss
    // first, get page directory entry
    PDIndex = (VPN & PD_MASK) >> PD_SHIFT
    PDEAddr = PDBR + (PDIndex * sizeof(PDE))
    PDE = AccessMemory(PDEAddr)
    if (PDE.Valid == False)
        RaiseException(SEGMENTATION_FAULT)
    else
    // PDE is valid: now fetch PTE from page table
        PTIndex = (VPN & PT_MASK) >> PT_SHIFT
        PTEAddr = (PDE.PFN << SHIFT) + (PTIndex * sizeof(PTE))
        PTE = AccessMemory(PTEAddr)
    if (PTE.Valid == False)
        RaiseException(SEGMENTATION_FAULT)
    else if (CanAccess(PTE.ProtectBits) == False)
        RaiseException(PROTECTION_FAULT)
    else
        TLB_Insert(VPN, PTE.PFN, PTE.ProtectBits)
        RetryInstruction()
```
#### 단점
- 시간과 공간 사이에서의 균형
    - 하나가 좋아지면 하나가 안 좋아짐
    - TLB miss에서 2번의 메모리 로드가 있음
- 복잡성
    - 하드웨어 또는 OS가 page table을 다루든지 복잡하기에 오버헤드가 생김

#### 예시
- Address Space
    - 16KB의 address space (64-byte page)
        - 14-bit addresssing
            - 6-bit offset
            - 8-bit VPN
    - 각 PTE는 4 byte
        - 한 page에 16개의 PTE 존재 가능
- Page table
    - Linear page table
        - $2^8(=256)$ entries
        - $256\times 4$ B = 1KB
    - Multi-level page tables
        - 각 page는 16 PTE
            - 13~06: VPN
                - 13~10: page directory index
                - 09~06: page table index
            - 05~00: Offset

# Multi-Level Page Tables (3)
## x86-32 (2-Level Paging)
- 32 bits
    - 10bits / 10bits / 12bits
        - page directory (1024 PDEs)
        - page table (1024 PTEs)
        - 4KB offset
    - CR3 레지스터: 현재 실행 중인 프로세스의 Page Directory Base를 가리킴
- 32bit addresssing -> 4GB만큼의 address space 배정
    - Kernel Space: 1GB
        - 커널 영역은 모든 프로세스가 공유
        - PID가 0인, IDLE Process가 있음
            - 시스템이 실행될 때 처음 생긴 프로세스 (커널 영역에서만 실행, 큐에 아무것도 없는 경우 실행)
    - User Space: 3GB
## x86-64 (4-Level Paging)
- 48 bits
    - ... / 9bits / 9bits / 9bits / 9bits / 12bits
        - entry 크기가 2배로 늘어남 / 개수 2배로 줄음
        - page map level 4
        - page directory pointer table
        - page directory
        - page table
        - offset
    - Kernel Space: 128TB
    - Noncanonical Space
    - User Space: 128TB
