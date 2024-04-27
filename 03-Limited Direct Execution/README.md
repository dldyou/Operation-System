# Limited Direct Execution (1)
## Direct Execution
<table>
    <tr>
        <th>OS</th>
        <th>Program</th>
    </tr>
    <tr>
        <td>
<pre>
Create entry for process list 
Allocate memory for program 
Load program into memory 
Set up stack with argc/argv 
Clear registers 
Execute <span style="color:red">call</span> main() 
</pre>
        </td>
        <td></td>
    </tr>
    <tr>
        <td></td>
        <td> 
<pre>
Run main() 
Execute <span style="color:red">return</span> from main()
</pre> 
        </td>
    </tr>
    <tr>
        <td> 
<pre>
Free memory of process 
Remove from process list
</pre> 
        </td>
        <td></td>
    </tr>
</table>

- 프로그램을 실행하는데 `limits`가 없다면 OS는 어떤 것도 제어하지 않을 것이고, 그러므로 단순한 라이브러리가 될 것이다.
    - OS는 어떻게 하면 프로그램을 효율적으로 실행하면서, 우리가 원하지 않는 일을 하지 않는지 확인할 수 있을까?
    - OS가 실행을 중지하고 다른 프로세스(즉, time sharing)로 전환하는 방법은 무엇일까?

<table>
    <tr>
        <th>OS</th>
        <th>Program</th>
    </tr>
    <tr>
        <td>
<pre>
Execute <span style="color:red">call</span> main()
</pre>
        </td>
        <td></td>
    </tr>
    <tr>
        <td>
<pre style="color:red"> 
Wait!
(Mechanism)
</pre>
        </td>
        <td>
<pre>
Run main()
...
...
...
Execute <span style="color:red">return</span> from main()
</pre>
        </td>
    </tr>
</table>

<table>
    <tr>
        <th>OS</th>
        <th>Program</th>
    </tr>
    <tr>
        <td>
<pre>
Execute <span style="color:red">call</span> main()
</pre>
        </td>
        <td></td>
    </tr>
    <tr>
        <td>
<pre style="color:red"> 
Let me see if
(Policy)
- Restricted operations
- Time sharing
</pre>
        </td>
        <td>
<pre>
Run main()
...
...
...
Execute <span style="color:red">return</span> from main()
</pre>
        </td>
    </tr>
</table>

# Limited Direct Execution (2)
## Problem #1: Restricted Operations
- 어떻게 제한된 작업을 수행할까?
    - Restricted operations (previleged operation)
        - 디스크에 `I/O` 요청을 보냄
        - CPU 또는 메모리 같은 더 많은 시스템 자원에 대한 접근 얻기
    - 어플리케이션은 제한된 작업을 수행할 수 있어야 하지만, 프로세스에 시스템에 대한 완전한 제어 권한을 부여하지 않아야 한다.

### Processor Modes
`User mode`
- user mode에서 실행되는 코드는 할 수 있는 작업이 제한됨
- 제한된 작업으로 인해 프로세서에서 예외가 발생함

`Kernel mode`
- 이 모드에서 코드는 시스템의 모든 기능을 사용할 수 있음
- OS는 이 모드에서 실행됨

> Previlege rings for the x86 <br>
Level 0: Operation system kernel <br>
... <br>
Level 3: Applications

### System Calls
#### user process가 privileged operation을 수행하려면 어떻게 해야 할까?
- System calls
    - `Trap instruction`
        - kernel로 이동
        - 권한 수준을 커널 모드로 높임
    - `Return-from-trap instruction`
        - 호출한 사용자 프로그램으로 돌아감
        - 권한 수준을 유저 모드로 낮춤

#### trap은 OS내에서 실행할  코드를 어떻게 알 수 있을까?
- 호출한 프로세스는 `jump to` 하는 주소를 특정할 수 없음
- `Trap table`
    - machine이 켜질 때, OS는 `trap handler`의 위치를 하드웨어에 알려줌
        - Privileged operaion
    - `system-call number`가 각 system call에 할당됨
    - user code는 `jump to` 할 정확한 주소를 지정할 수 없으며, system-call number를 통해 특정 서비스를 요청해야 함
### Limited Direct Execution Protocol
<table>
    <tr>
        <th>OS</th>
        <th>Hardware</th>
        <th>Program</th>
    </tr>
    <tr>
        <td>
<pre style="color:red">
Initialize trap table
</pre>
        </td>
        <td></td>
        <td></td>
    </tr>
    <tr>
        <td></td>
        <td>
<pre>
Remeber address of syscall handler
</pre>
        </td>
        <td></td>
    </tr>
    <tr>
        <td>
<pre>
Create entry for process list
Allocate memory for program
Load program into memory
Set up user stack with argc/argv
<span style=color:blue>Fill kernel stack with regs/PC</span>
<span style=color:red>Return-from-trap</span>
</pre>
        </td>
        <td></td>
        <td></td>
    </tr>
    <tr>
        <td></td>
        <td>
<pre>
<span style=color:blue>Restore regs from kernel stack</span>
<span style=color:red>Move to user mode</span>
Jump to main
</pre>
        </td>
        <td></td>
    </tr>
    <tr>
        <td></td>
        <td></td>
        <td>
<pre>
Run main()
...
Call system call
<span style=color:red>Trap</span> into OS
</pre>
        </td>
    </tr>
    <tr>
        <td></td>
        <td>
<pre>
<span style=color:blue>Save regs/PC to kernel stack</span>
<span style=color:red>Move to kernel mode</span>
Jump to trap handler
</pre>
        </td>
        <td></td>
    </tr>
    <tr>
        <td>
<pre>
Handle trap
<span style=color:red>Return-from-trap</span>
</pre>
        </td>
        <td></td>
        <td></td>
    </tr>
    <tr>
        <td></td>
        <td>
<pre>
<span style=color:blue>Restore regs from kernel stack</span>
<span style=color:red>Move to user mode</span>
Jump to PC after trap
</pre>
        </td>
        <td></td>
    </tr>
    <tr>
        <td></td>
        <td></td>
        <td>
<pre>
Return from main()
<span style=color:red>Trap</span> (via exit())
</pre>
        </td>
    </tr>
    <tr>
        <td>
<pre>
Free memory of process
Remove from process list
</pre>
        </td>
        <td></td>
        <td></td>
    </tr>
</table>

# Limited Direct Execution (3)
## Problem #2: Switching Between Processes
- 어떻게 CPU의 제어를 다시 얻을 수 있을까?
    - 만약, 프로세스가 CPU에서 실행 중이라면 OS가 실행하지 않고 있다는 의미임
    - 만약 OS가 실행 중이 아니라면, 아무 것도 할 수 없을까?

### Cooperative Approach
- system calls을 기다린다
    - 너무 오랫동안 실행되는 프로세스는 CPU를 주기적으로 포기하는 것으로 가정
        - 대부분의 프로세스는 system call에 의해 CPU에서 OS로 제어를 자주 전환함
        - 명시적 양보 system call
- 에러를 기다린다
    - 어플리케이션은 부적절한 작업을 수행하면 OS로 제어가 넘어간다
        - 0으로 나누기
        - segementation fault

### Non-Cooperative Approach
- OS가 강제로 제어를 가져온다
    - Timer interrupt
        - timer 장치는 주기적으로 인터럽트를 발생하도록 설정할 수 있음
        - 인터럽트가 발생하면 실행 중인 프로세스는 중단되고, `pre-configured interrupt handler`가 실행됨

### Context Switch
- Context의 저장과 복구
    - `currently-executing` 프로세스의 몇 개의 레지스터 값들을 저장 (kernel stack에)
    - `soon-to-be-executing` 프로세스에 몇 개의 레지스터 값들을 복구 (kernel stack에서)
    - `return-from-trap` 명령어가 실행될 때, 시스템이 다른 프로세스의 실행을 재개하는 것을 보장함

### Limited Direct Execution Protocol
<table>
    <tr>
        <th>OS</th>
        <th>Hardware</th>
        <th>Program</th>
    </tr>
    <tr>
        <td>
<pre style=color:red>
Initialize trap table
</pre>
        </td>
        <td></td>
        <td></td>
    </tr>
    <tr>
        <td></td>
        <td>
<pre>
Remeber address of
    syscall handler
    timer handler
</pre>
        </td>
        <td></td>
    </tr>
    <tr>
        <td>
<pre style=color:red>
Start interrupt timer
</pre>
        </td>
        <td></td>
        <td></td>
    </tr>
    <tr>
        <td></td>
        <td>
<pre>
Start timer
(interrupt CPU in X ms)
</pre>
        </td>
        <td></td>
    </tr>
    <tr>
        <td>
<pre>
...
</pre>
        </td>
        <td></td>
        <td>
<pre>
Process A
</pre>
        </td>
    </tr>
    <tr>
        <td></td>
        <td>
<pre>
<span style=color:red>Timer interrupt</span>
<span style=color:blue>Save Uregs(A) to kernel stack</span>
<span style=color:red>Move to kernel mode</span>
Jump to trap handler
</pre>
        </td>
        <td></td>
    </tr>
    <tr>
        <td>
<pre>
Handle the trap
<span style=color:red>Call switch() routine</span>
<span style=color:blue>
    save Kregs(A) to k-stack(A)*
    restore Kregs(B) from k-stack(B)*
    switch to k-stack(B)
</span>
<span style=color:red>Return-from-trap (into B)</span>
</pre>
        </td>
        <td></td>
        <td></td>
    </tr>
    <tr>
        <td></td>
        <td>
<pre>
<span style=color:blue>Restore Uregs(B) from kernel stack</span>
<span style=color:red>Move to user mode</span>
Jump to B's PC
</pre>
        </td>
        <td></td>
    </tr>
    <tr>
        <td></td>
        <td></td>
        <td>
<pre>
Process B
</pre>
        </td>
    </tr>
</table>