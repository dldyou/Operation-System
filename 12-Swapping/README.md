## Demand Paging
- OS는 메모리에 접근할 때 그 page만 가져옴
- page가 invalid (not present)하면 page fault가 일어남
- page fault가 초반에 많이 발생할 수 있기에, prefetching을 통해 미리 가져옴 (ex. P를 접근할 때, P+1도 가져옴)
# Swapping (1)
- 메모리는 유한하기에 사용하지 않는 것은 잠시 빼놓아야 함
## Swap space
- 디스크에 존재하며, 필요하지 않은 page를 집어넣고 필요하면 빼냄
- swap out: 필요없는 것을 빼는 것
- swap in: 필요한 것을 가져오는 것
- swap을 할 때에도 page-size 단위로 진행
- OS는 어디서 page가 disk의 어디에 있는지 기억해야 함

### Present Bit
- 해당 page가 메모리 상에 적재되어 있는지를 판단하는 비트
    - 0이라면 메모리가 아닌 디스크(swap space)에 있다는 것임

### Page fault
- present bit가 0이면 page fault 발생
- page-fault handler 실행
### Page-fault handler
- swap space로 빠진 page를 swap in 하도록 함
- page fault를 발생시킨 것은 blocked state로 옮김 (메모리 접근해야 해서 느리기에)
### Page Fault Control Flow (Hardware)
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
    PTEAddr = PTBR + (VPN * sizeof(PTE))
    PTE = AccessMemory(PTEAddr)
    if (PTE.Valid == False)
        RaiseException(SEGMENTATION_FAULT)
    else
        if (CanAccess(PTE.ProtectBits) == False)
            RaiseException(PROTECTION_FAULT)
        else if (PTE.Present == True)
            // assuming hardware-managed TLB
            TLB_Insert(VPN, PTE.PFN, PTE.ProtectBits)
            RetryInstruction()
        else if (PTE.Present == False)
            RaiseException(PAGE_FAULT)
```
- page fault handler (software)
```C
PFN = FindFreePhysicalPage()
if (PFN == -1) // no free page found
    PFN = EvictPage() // run replacement algorithm
DiskRead(PTE.DiskAddr, PFN) // sleep (waiting for I/O)
PTE.present = True // update page table with present
PTE.PFN = PFN // bit and translation (PFN)
RetryInstruction() // retry instruction
```
- page fault 발생 시 기본적으로 2번 retry 진행

# Swapping (2)
## Page Replacement
- 메모리가 꽉차면?
    - 한 개 또는 그 이상의 page를 swap out 해서 새로운 page가 들어갈 공간을 만들어야 함
- 실제로 replacemnet가 일어나는가? (위의 메모리가 꽉찬 경우)
    - Hight Watermark (HW) 와 Low Watermark (LW)
    - Swap daemon 
        - LW 보다 적은 page가 남아있으면 memory free를 시킴
        - HW 만큼을 유지하려고 함
- 어떻게 뺄 page를 정할지
    - 잘못된 선택을 하면 뺏던 page가 바로 다음에 필요한 경우가 생겨 느릴 수 있음

## Page Replacement 정책
- Optimal replacement policy 
    - 향후에 가장 오랫동안 사용되지 않을 것을 evict (비현실적이긴 함)
- FIFO
    - 가장 먼저 들어온 것을 evict
        - Belady's anomaly: 매핑될 수 있는 큐 크기가 커지면 hit rate가 나빠짐
        - 1, 2, 3, 4, 1, 2, 5, 1, 2, 3, 4, 5
            - queue size 3: 9 
            - queue size 4: 10
- Least-Frequently-Used(LFU)
    - 가장 적에 사용된 것 evict
- Least-Recently Used(LRU)
    - 가장 오래 전에 사용된 것 evict
- 기록 기반 알고리즘: LFU, LRU
    - PTE 또는 다른 분리된 배열에 기록을 저장해야함
    - PTE에 넣기에는 큰 사이즈의 정보라 적절하지 않음
    - 현실적으로 정확히 구현하기는 어려움
- Approximating LRU
    - Clock 알고리즘
    - bit 1개 사용해서 진행
        - replace가 필요하면 시계방향으로 돌면서
            - bit가 1이면 0으로 만듦
            - bit가 0이면 해당 자리에 bit 1로 mapping 시킴
- dirty page 고려
    - page가 수정되지 않았다면 추가적인 I/O 없이 다른 목적으로 재사용할 수 있음