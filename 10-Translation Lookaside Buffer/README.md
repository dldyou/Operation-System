# Translation-Lookaside Buffer (1)
## Paging
- address space는 작고 고정된 크기의 유닛(page frame)으로 쪼갬
- 큰 양의 매핑 정보가 필요함
    - 물리 메모리에 저장
    - 각 virtual address 마다 추가적인 메모리가 필요함
- address translation을 어떻게 빠르게 할 수 있을까?
    - 하드웨어
    - OS 

## Translation-Lookaside Buffer (TLB)
- CPU에 구현된 `Memory Management Unit (MMU)` 중 일부
    - `MMU` : address space를 지원해주기 위해 하드웨어가 지원하고 있는 모든 것
- `Address-translation cache`
    - 메모리에 존재하는 page table을 접근하는 대신, 자주 접근하는 것은 캐시에 저장된 값으로 진행

### 기본 알고리즘
- linear page table을 가정 (table 1개)
    ```C
    VPN = (VirtualAddress & VPN_MASK) >> SHIFT
    (Success, TlbEntry) = TLB_Lookup(VPN)
    if (Success == True) // TLB hit
        if (CanAccess(TlbEntry.ProtectBits) == True)
            offset = VirtualAddress & OFFSET_MASK
            PhysAddr = (TlbEntry.PFN << SHIFT) | offset
            Register = AccessMemory(PhysAddr)
    else
        RaiseException(PROTECTION_FAULT)
    else // TLB miss
        PTEAddr = PTBR + (VPN * sizeof(PTE))
        PTE = AccessMemory(PTEAddr)
    if (PTE.Valid == False)
        RaiseException(SEGMENTATION_FAULT)
    else if (CanAccess(PTE.ProtectBits) == False)
        RaiseException(PROTECTION_FAULT)
    else
        TLB_Insert(VPN, PTE.PFN, PTE.ProtectBits)
        RetryInstruction()
    ```
    - 이전과 달리 TLB에 있는지 확인 
        - 있으면 TLB hit
        - 없으면 TLB miss
            - TLB를 채우고 나서 바로 메모리 접근이 아닌 다시 TLB를 확인해서 hit가 되는 방식으로 진행

#### 예시
- 간단한 virtual address space
    - 8-bit addressing
        - 상위 4-bit: PFN
        - 하위 4-bit: offset
- 각 4-byte 짜리 10개인 배열
    - virtual address 100번지에서 시작 (VPN 06, 04번지)
    - a[0]: VPN 06, 04번지
    - a[1]: VPN 06, 08번지
    - a[2]: VPN 06, 12번지
    - a[3]: VPN 07, 00번지
    - ...
    - a[9]: VPN 08, 08번지
- 간단한 반복
    ```C
    int sum = 0;
    for (i = 0; i < 10; i++){
        sum += a[i];
    }
    ```
    - hit rate: 70%
    - a[0], a[3], a[7]에서 miss

### TLB miss는 누가 다루는가?
- **hardware-managed TLB**
    - CISC (즉, x86)
    - 하드웨어는 page table이 메모리에 어디에 위치한지(PTBR로 알 수 있음)와 정확한 형태를 알아야 함
        - x86에서 CR3와 multi-level page table
- **software-managed TLB**
    - RISC (즉, MIPS)
    ```C
    VPN = (VirtualAddress & VPN_MASK) >> SHIFT
    (Success, TlbEntry) = TLB_Lookup(VPN)
    if (Success == True) // TLB hit
        if (CanAccess(TlbEntry.ProtectBits) == True)
            offset = VirtualAddress & OFFSET_MASK
            PhysAddr = (TlbEntry.PFN << SHIFT) | offset
            Register = AccessMemory(PhysAddr)
    else
        RaiseException(PROTECTION_FAULT)
    else // TLB miss
        RaiseException(TLB_MISS)
    ```
    - TLB update를 하는 것은 privileged 명령어여야 함
    - miss 되면 바로 exception (따로 TLB에 insert 해줘야 함)

### TLB에 들어있는 정보
- Fully associative
    - 어떤 translation이 있는 TLB에 빈공간이 있으면 들어갈 수 있음
    - 하드웨어는 특정 TLB를 찾을 때, 모든 TLB를 병렬적으로 찾음
- VPN | PFN | other bits
    - Valid bit: 유효한 VPN, PFN값을 가지고 있는지
    - Protection bits: page table에 어떻게 접근할 수 있는지 (read, write, ...)
    - Address-space id, dirty bit, ... 

### Context Switch
|process|VPN|PFN|valid|prot|
|:-:|:-:|:-:|:-:|:-:|
|P1|10|100|1|rwx|
|-|-|-|0|-|
|P2|10|170|1|rwx|
|-|-|-|0|-|
- 하드웨어는 P1과 P2를 구별하지 못함
- valid가 0인 곳의 VPN과 PFN은 유효하지 않은 값임
- context switch가 일어날때마다 이러한 중복되는 것에 대해 모두 valid를 0으로 flush 해줘야 함
    - 오버헤드 커짐

- Address space identifier (ASID)
    |process|VPN|PFN|valid|prot|ASID|
    |:-:|:-:|:-:|:-:|:-:|:-:|
    |P1|10|100|1|rwx|1|
    |-|-|-|0|-|-|
    |P2|10|170|1|rwx|2|
    |-|-|-|0|-|-|

### Sharing Page
- 메모리 오버헤드를 줄이기 위해 physical page를 공유하기도 함
    - binaries, shared libraries, fork()
- Shared memory IPC
    |process|VPN|PFN|valid|prot|ASID|
    |:-:|:-:|:-:|:-:|:-:|:-:|
    |P1|10|101|1|r-x|1|
    |-|-|-|0|-|-|
    |P2|50|101|1|r-x|2|
    |-|-|-|0|-|-|

### Replacement 정책
- 새로운 TLB entry를 추가할 때, 어떤 TLB entry를 대체할지
- TLB miss rate를 줄이는 쪽으로 해야 함

#### Least-Recently-Used (LRU)
- 최근에 가장 적게 사용된 것부터 교체
- TLB 엔트리 개수가 n일때, n + 1개 이상의 엔트리를 접근하는 것을 반복할 때
    - 계속해서 miss가 나게 됨
#### Random  
- 랜덤으로 교체

#### MIPS TLB entry
    - 00~18: VPN
    - 19: G
    - 24~31: ASID <br><br>
    - 02~25: PFN
    - 26~28: C
    - 29: D
    - 30: V <br><br>
    - 32-bit address space (4KB page)
        - 20-bit: VPN
        - 12-bit: offset
    - PFN
        - 24-bit (64GB main memory addressing 가능)
    - Global bit(G)
        - VPN이 G를 포함한 20-bit
        - 1인 경우 공유되는 process 전체적으로 공유됨 (ex. 커널)
    - ASID bits
        - address space를 구분하기 위해 사용
        - PID보다 적은 8bit 사용
            - 생성 가능한 프로세스 개수가 ASID보다 작도록 진행
            - ASID보다 많은 프로세스가 생기면 ASID를 안 씀
            - ASID와 PID를 일대일로 매칭시키는 것이 아닌 각각 실행할 때마다 dynamic하게 맞춤
    - Coherence bits (C)
        - 캐시 정보
    - Dirty bit (D)
        - write operation이 발생했는지
    - Valid bit (V)
        - VPN와 PFN의 매핑이 유효한지
