# 🖥️ RISC-V Multi-Cycle CPU & APB 프로젝트 완벽 면접 대비 가이드

## 목차
1. [프로젝트 핵심 요약](#1-프로젝트-핵심-요약)
2. [RISC-V 아키텍처 완벽 정리](#2-risc-v-아키텍처-완벽-정리)
3. [Multi-Cycle CPU 설계](#3-multi-cycle-cpu-설계)
4. [APB 버스 프로토콜](#4-apb-버스-프로토콜)
5. [Peripheral 설계](#5-peripheral-설계)
6. [코드 상세 분석](#6-코드-상세-분석)
7. [Trouble Shooting](#7-trouble-shooting)
8. [면접 예상 질문 & 답변](#8-면접-예상-질문--답변)

---

# 1. 프로젝트 핵심 요약

## 1.1 프로젝트 한 줄 설명
**"RISC-V RV32I 기반 Multi-Cycle CPU를 설계하고, APB 버스를 통해 UART, GPIO 등의 Peripheral을 제어하는 완전한 SoC 시스템 구현"**

## 1.2 핵심 성과
- ✅ **RISC-V RV32I** 37개 명령어 모두 구현
- ✅ **Multi-Cycle FSM** 15개 상태로 최적화
- ✅ **APB 버스 프로토콜** Master/Slave 구현
- ✅ **UART with FIFO** 실시간 통신
- ✅ **FPGA 실제 동작** 검증 (LED 제어)

## 1.3 시스템 구성 요소

| 구성 요소 | 설명 | 파일 |
|----------|------|------|
| **CPU Core** | RISC-V RV32I Multi-Cycle | CPU_RV32I.sv |
| **Control Unit** | 15-state FSM | ControlUnit.sv |
| **DataPath** | Register File, ALU, Mux | DataPath.sv |
| **APB Master** | 3-state FSM (IDLE-SETUP-ACCESS) | APB_Master.sv |
| **APB Slave** | RAM, UART, GPO, GPI | APB_Slave.sv, UART.sv, GPO.sv |
| **Memory** | ROM (Code), RAM (Data) | ROM.sv, RAM.sv |
| **Reset System** | POR + Debouncer | MCU.sv |

---

# 2. RISC-V 아키텍처 완벽 정리

## 2.1 RISC-V란?

### 📌 RISC-V 소개
- **오픈소스 ISA (Instruction Set Architecture)**
- **UC Berkeley**에서 개발
- **모듈식 설계**: Base ISA + Extensions
- **무료**: 라이선스 비용 없음

### 📌 RISC vs CISC

| 항목 | RISC | CISC |
|------|------|------|
| **명령어 수** | 적음 (100개 미만) | 많음 (수백 개) |
| **명령어 길이** | 고정 | 가변 |
| **실행 시간** | 대부분 1 cycle | 여러 cycle |
| **예시** | RISC-V, ARM | x86, x86-64 |

### 📌 왜 Multi-Cycle?

| 방식 | Single-Cycle | Multi-Cycle | Pipelined |
|------|-------------|-------------|-----------|
| **CPI** | 1 (모든 명령어) | 3~5 (평균) | ~1 (이상적) |
| **Clock** | 가장 느린 명령어 기준 | 각 단계별 최적화 | 각 단계별 최적화 |
| **복잡도** | 낮음 | 중간 | 높음 |
| **성능** | 낮음 | 중간 | 높음 |

**본 프로젝트 선택 이유:**
- 교육 목적으로 FSM 설계 경험
- Pipeline Hazard 없이 명확한 동작
- 리소스 효율적

---

## 2.2 RISC-V RV32I 명령어 세트

### 📌 RV32I Base ISA
**32-bit Integer Instructions** (37개)

#### 1. R-Type (Register-Register)
**형식:** `rd = rs1 OP rs2`

| 명령어 | 기능 | 예시 |
|--------|------|------|
| ADD | 덧셈 | `add x1, x2, x3` → x1 = x2 + x3 |
| SUB | 뺄셈 | `sub x1, x2, x3` → x1 = x2 - x3 |
| AND | 논리 AND | `and x1, x2, x3` → x1 = x2 & x3 |
| OR | 논리 OR | `or x1, x2, x3` → x1 = x2 \| x3 |
| XOR | 논리 XOR | `xor x1, x2, x3` → x1 = x2 ^ x3 |
| SLL | 논리 왼쪽 시프트 | `sll x1, x2, x3` → x1 = x2 << x3 |
| SRL | 논리 오른쪽 시프트 | `srl x1, x2, x3` → x1 = x2 >> x3 |
| SRA | 산술 오른쪽 시프트 | `sra x1, x2, x3` → x1 = x2 >>> x3 |
| SLT | Set Less Than | `slt x1, x2, x3` → x1 = (x2 < x3) ? 1 : 0 |
| SLTU | Set Less Than Unsigned | `sltu x1, x2, x3` |

**Opcode:** `0110011`

#### 2. I-Type (Immediate)
**형식:** `rd = rs1 OP imm`

| 명령어 | 기능 | 예시 |
|--------|------|------|
| ADDI | 즉시값 덧셈 | `addi x1, x2, 10` → x1 = x2 + 10 |
| ANDI | 즉시값 AND | `andi x1, x2, 0xFF` |
| ORI | 즉시값 OR | `ori x1, x2, 0x10` |
| XORI | 즉시값 XOR | `xori x1, x2, -1` |
| SLLI | 즉시값 왼쪽 시프트 | `slli x1, x2, 5` |
| SRLI | 즉시값 논리 오른쪽 시프트 | `srli x1, x2, 3` |
| SRAI | 즉시값 산술 오른쪽 시프트 | `srai x1, x2, 2` |
| SLTI | Set Less Than Immediate | `slti x1, x2, 100` |
| SLTIU | SLTI Unsigned | `sltiu x1, x2, 50` |

**Opcode:** `0010011`

#### 3. L-Type (Load)
**형식:** `rd = MEM[rs1 + imm]`

| 명령어 | 기능 | 예시 |
|--------|------|------|
| LW | Word 로드 (32-bit) | `lw x1, 0(x2)` → x1 = MEM[x2] |
| LH | Halfword 로드 (16-bit, sign-ext) | `lh x1, 4(x2)` |
| LB | Byte 로드 (8-bit, sign-ext) | `lb x1, 8(x2)` |
| LHU | Halfword Unsigned | `lhu x1, 2(x2)` |
| LBU | Byte Unsigned | `lbu x1, 1(x2)` |

**Opcode:** `0000011`

#### 4. S-Type (Store)
**형식:** `MEM[rs1 + imm] = rs2`

| 명령어 | 기능 | 예시 |
|--------|------|------|
| SW | Word 저장 (32-bit) | `sw x1, 0(x2)` → MEM[x2] = x1 |
| SH | Halfword 저장 (16-bit) | `sh x1, 4(x2)` |
| SB | Byte 저장 (8-bit) | `sb x1, 8(x2)` |

**Opcode:** `0100011`

#### 5. B-Type (Branch)
**형식:** `if (rs1 OP rs2) PC += imm`

| 명령어 | 기능 | 예시 |
|--------|------|------|
| BEQ | Branch if Equal | `beq x1, x2, label` |
| BNE | Branch if Not Equal | `bne x1, x2, label` |
| BLT | Branch if Less Than | `blt x1, x2, label` |
| BGE | Branch if Greater or Equal | `bge x1, x2, label` |
| BLTU | BLT Unsigned | `bltu x1, x2, label` |
| BGEU | BGE Unsigned | `bgeu x1, x2, label` |

**Opcode:** `1100011`

#### 6. U-Type (Upper Immediate)
**형식:** `rd = imm << 12`

| 명령어 | 기능 | 예시 |
|--------|------|------|
| LUI | Load Upper Immediate | `lui x1, 0x12345` → x1 = 0x12345000 |
| AUIPC | Add Upper Immediate to PC | `auipc x1, 0x1000` → x1 = PC + 0x1000000 |

**Opcode:** LUI=`0110111`, AUIPC=`0010111`

#### 7. J-Type (Jump)
**형식:** `rd = PC + 4; PC += imm`

| 명령어 | 기능 | 예시 |
|--------|------|------|
| JAL | Jump and Link | `jal x1, label` → x1 = PC+4, PC = label |
| JALR | Jump and Link Register | `jalr x1, 0(x2)` → x1 = PC+4, PC = x2 |

**Opcode:** JAL=`1101111`, JALR=`1100111`

### 📌 명령어 포맷

```
R-Type: funct7(7) | rs2(5) | rs1(5) | funct3(3) | rd(5) | opcode(7)
I-Type: imm[11:0](12)      | rs1(5) | funct3(3) | rd(5) | opcode(7)
S-Type: imm[11:5](7) | rs2(5) | rs1(5) | funct3(3) | imm[4:0](5) | opcode(7)
B-Type: imm[12,10:5](7) | rs2(5) | rs1(5) | funct3(3) | imm[4:1,11](5) | opcode(7)
U-Type: imm[31:12](20)     | rd(5) | opcode(7)
J-Type: imm[20,10:1,11,19:12](20) | rd(5) | opcode(7)
```

### 📌 Register File
- **32개 레지스터**: x0 ~ x31
- **x0**: 항상 0 (하드와이어드)
- **x1 (ra)**: Return Address
- **x2 (sp)**: Stack Pointer
- **x8-x9, x18-x27**: Saved Registers
- **x10-x17**: Argument Registers

---

# 3. Multi-Cycle CPU 설계

## 3.1 Multi-Cycle 개념

### 📌 Single-Cycle vs Multi-Cycle

**Single-Cycle:**
```
┌─────────────────────────────────────────────┐
│ Fetch → Decode → Execute → Memory → WriteBack │
└─────────────────────────────────────────────┘
        (한 클럭에 모두 완료)
```

**Multi-Cycle:**
```
Cycle 1: Fetch
Cycle 2: Decode
Cycle 3: Execute
Cycle 4: Memory (필요시)
Cycle 5: WriteBack (필요시)
```

### 📌 Multi-Cycle 장점
1. **클럭 속도 향상**: 가장 긴 단계만 고려
2. **리소스 재사용**: ALU, Memory를 여러 단계에서 공유
3. **명령어별 최적화**: 간단한 명령어는 빠르게

### 📌 본 프로젝트 CPI (Cycles Per Instruction)

| 명령어 타입 | Cycles | 경로 |
|------------|--------|------|
| **R-Type** | 3 | FETCH → DECODE → R_EXE |
| **I-Type** | 3 | FETCH → DECODE → I_EXE |
| **B-Type** | 3 | FETCH → DECODE → B_EXE |
| **U-Type (LUI)** | 3 | FETCH → DECODE → LU_EXE |
| **U-Type (AUIPC)** | 3 | FETCH → DECODE → AU_EXE |
| **J-Type (JAL)** | 3 | FETCH → DECODE → J_EXE |
| **J-Type (JALR)** | 3 | FETCH → DECODE → JL_EXE |
| **S-Type (Store)** | 5 | FETCH → DECODE → S_EXE → S_MEM → MEMORY_DELAY |
| **L-Type (Load)** | 6 | FETCH → DECODE → L_EXE → L_MEM → L_WB → MEMORY_DELAY |

**평균 CPI:** 약 3.5 cycles

---

## 3.2 Control Unit (FSM) 설계

### 📌 FSM 상태 다이어그램

```
          ┌────────┐
          │ FETCH  │ ← 모든 명령어 시작
          └───┬────┘
              ↓
          ┌────────┐
          │ DECODE │ ← Opcode 해석
          └───┬────┘
              ↓
    ┌─────────┴──────────────┬──────────────┬─────────┐
    ↓                        ↓              ↓         ↓
┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐
│ R_EXE │  │ I_EXE │  │ B_EXE │  │LU_EXE │  │AU_EXE │ ...
└───┬───┘  └───┬───┘  └───┬───┘  └───┬───┘  └───┬───┘
    │          │          │          │          │
    └──────────┴──────────┴──────────┴──────────┘
                          ↓
                     ┌────────┐
                     │ FETCH  │ (3 cycles)
                     └────────┘


                ┌───────┐       ┌───────┐
                │ S_EXE │───────→│ S_MEM │
                └───────┘       └───┬───┘
                                    ↓
                               ┌─────────────┐
                               │MEMORY_DELAY │
                               └──────┬──────┘
                                      ↓
                                 ┌────────┐
                                 │ FETCH  │ (5 cycles)
                                 └────────┘


                ┌───────┐       ┌───────┐       ┌──────┐
                │ L_EXE │───────→│ L_MEM │──────→│ L_WB │
                └───────┘       └───────┘       └───┬──┘
                                                    ↓
                                               ┌─────────────┐
                                               │MEMORY_DELAY │
                                               └──────┬──────┘
                                                      ↓
                                                 ┌────────┐
                                                 │ FETCH  │ (6 cycles)
                                                 └────────┘
```

### 📌 제어 신호

| 신호 | 의미 |
|------|------|
| **PCEn** | PC Enable (PC 업데이트) |
| **regFileWe** | Register File Write Enable |
| **aluControl[3:0]** | ALU 연산 선택 |
| **aluSrcMuxSel** | ALU 입력 선택 (rs2 or imm) |
| **busWe** | Memory Write Enable |
| **RFWDSrcMuxSel[2:0]** | Register File Write Data 선택 |
| **branch** | Branch 명령어 플래그 |
| **jal** | JAL 명령어 플래그 |
| **jalr** | JALR 명령어 플래그 |
| **transfer** | APB 전송 시작 |

### 📌 코드 분석: ControlUnit.sv

```systemverilog
// FSM 상태 정의
typedef enum {
    FETCH,         // 명령어 가져오기
    DECODE,        // 명령어 해석
    R_EXE,         // R-Type 실행
    I_EXE,         // I-Type 실행
    B_EXE,         // Branch 실행
    LU_EXE,        // LUI 실행
    AU_EXE,        // AUIPC 실행
    J_EXE,         // JAL 실행
    JL_EXE,        // JALR 실행
    S_EXE,         // Store 주소 계산
    S_MEM,         // Store 메모리 쓰기
    L_EXE,         // Load 주소 계산
    L_MEM,         // Load 메모리 읽기
    L_WB,          // Load Write Back
    MEMORY_DELAY   // Memory Access 후 대기
} state_e;

// 상태 전이 로직
always_comb begin
    next_state = state;
    case (state)
        FETCH:  next_state = DECODE;
        DECODE: begin
            case (opcode)
                `OP_TYPE_R:  next_state = R_EXE;
                `OP_TYPE_I:  next_state = I_EXE;
                `OP_TYPE_B:  next_state = B_EXE;
                `OP_TYPE_LU: next_state = LU_EXE;
                `OP_TYPE_AU: next_state = AU_EXE;
                `OP_TYPE_J:  next_state = J_EXE;
                `OP_TYPE_JL: next_state = JL_EXE;
                `OP_TYPE_S:  next_state = S_EXE;
                `OP_TYPE_L:  next_state = L_EXE;
            endcase
        end
        R_EXE:  next_state = FETCH;  // 3 cycles
        I_EXE:  next_state = FETCH;  // 3 cycles
        // ... (생략)
        S_EXE:  next_state = S_MEM;
        S_MEM:  if (ready) next_state = MEMORY_DELAY;
        L_EXE:  next_state = L_MEM;
        L_MEM:  if (ready) next_state = L_WB;
        L_WB:   next_state = MEMORY_DELAY;
        MEMORY_DELAY: next_state = FETCH;
    endcase
end

// 제어 신호 생성
always_comb begin
    signals = 11'b0;
    aluControl = `ADD;
    case (state)
        //{PCEn, regFileWe, aluSrcMuxSel, busWe, RFWDSrcMuxSel(3), branch, jal, jalr, transfer}
        FETCH:  signals = 11'b1_0_0_0_000_0_0_0_0;  // PC 업데이트
        DECODE: signals = 11'b0_0_0_0_000_0_0_0_0;  // 해석만
        R_EXE: begin
            signals = 11'b0_1_0_0_000_0_0_0_0;  // RF Write, ALU 결과 저장
            aluControl = operator;  // funct7 + funct3
        end
        I_EXE: begin
            signals = 11'b0_1_1_0_000_0_0_0_0;  // RF Write, ALU src = imm
            if (operator == 4'b1101) aluControl = operator;
            else aluControl = {1'b0, operator[2:0]};
        end
        // ... (생략)
        S_MEM:  signals = 11'b0_0_1_1_000_0_0_0_1;  // Memory Write, APB transfer
        L_MEM:  signals = 11'b0_0_1_0_001_0_0_0_1;  // Memory Read, APB transfer
        L_WB:   signals = 11'b0_1_1_0_001_0_0_0_0;  // RF Write, Memory data
    endcase
end
```

### 📌 왜 MEMORY_DELAY가 필요한가?
**문제:**
- APB 버스는 SETUP → ACCESS로 2 cycles 필요
- Memory Access 후 바로 FETCH로 가면 충돌

**해결:**
- MEMORY_DELAY 상태 추가
- 1 cycle 대기 후 FETCH

---

## 3.3 DataPath 설계

### 📌 DataPath 구조

```
                    ┌──────────────────────────────────────────┐
                    │          DataPath                         │
                    │                                           │
  instrCode ────────┼──▶ Decoder ──────┬──────────────────────┐ │
                    │                   │                      │ │
                    │         ┌─────────▼──────┐               │ │
                    │         │ Register File  │               │ │
                    │         │  (32 x 32-bit) │               │ │
                    │         └────┬───────┬───┘               │ │
                    │              │       │                   │ │
                    │         RD1  │       │ RD2               │ │
                    │              ↓       ↓                   │ │
                    │       ┌──────┴───────┴───────┐           │ │
                    │       │   Pipeline Regs      │           │ │
                    │       │  (DecReg_RFData1/2)  │           │ │
                    │       └──────┬───────┬───────┘           │ │
                    │              │       │                   │ │
                    │              │       └──────┐            │ │
                    │              │              ↓            │ │
                    │              │        ┌─────────┐        │ │
                    │              │        │   Mux   │        │ │
                    │              │        │(rs2/imm)│        │ │
                    │              │        └────┬────┘        │ │
                    │              │             │             │ │
                    │              └─────┬───────┘             │ │
                    │                    │                     │ │
                    │              ┌─────▼─────┐               │ │
                    │              │    ALU    │               │ │
                    │              │           │               │ │
                    │              │ +,-,&,|,^ │               │ │
                    │              │ <<,>>,>>> │               │ │
                    │              │  <, ==    │               │ │
                    │              └─────┬─────┘               │ │
                    │                    │                     │ │
                    │              ┌─────▼─────┐               │ │
                    │              │ ExeReg_   │               │ │
                    │              │ aluResult │               │ │
                    │              └─────┬─────┘               │ │
                    │                    │                     │ │
                    │                    ├──────▶ busAddr      │ │
                    │                    │                     │ │
                    │              ┌─────▼─────┐               │ │
                    │              │   Mux     │               │ │
                    │              │(RF Write  │               │ │
                    │              │ Data Src) │               │ │
                    │              └─────┬─────┘               │ │
                    │                    │                     │ │
                    │                    └──▶ WD (to RF)       │ │
                    │                                           │
  busRData ─────────┼──────────────────────────────────────────┤ │
                    │                                           │
                    └──────────────────────────────────────────┘
```

### 📌 주요 컴포넌트

#### 1. Register File
```systemverilog
module RegisterFile (
    input  logic        clk,
    input  logic        we,       // Write Enable
    input  logic [ 4:0] RA1,      // Read Address 1
    input  logic [ 4:0] RA2,      // Read Address 2
    input  logic [ 4:0] WA,       // Write Address
    input  logic [31:0] WD,       // Write Data
    output logic [31:0] RD1,      // Read Data 1
    output logic [31:0] RD2       // Read Data 2
);
    logic [31:0] mem[0:31];
    
    always_ff @(posedge clk) begin
        if (we) mem[WA] <= WD;
    end
    
    // x0는 항상 0
    assign RD1 = (RA1 != 0) ? mem[RA1] : 32'b0;
    assign RD2 = (RA2 != 0) ? mem[RA2] : 32'b0;
endmodule
```

#### 2. ALU
```systemverilog
module alu (
    input  logic [ 3:0] aluControl,
    input  logic [31:0] a, b,
    output logic [31:0] result,
    output logic        btaken    // Branch Taken
);
    always_comb begin
        result = 32'bx;
        case (aluControl)
            `ADD:  result = a + b;
            `SUB:  result = a - b;
            `SLL:  result = a << b;
            `SRL:  result = a >> b;
            `SRA:  result = $signed(a) >>> b;  // 산술 시프트
            `SLT:  result = ($signed(a) < $signed(b)) ? 1 : 0;
            `SLTU: result = (a < b) ? 1 : 0;
            `XOR:  result = a ^ b;
            `OR:   result = a | b;
            `AND:  result = a & b;
        endcase
    end
    
    // Branch 조건 계산
    always_comb begin
        btaken = 1'b0;
        case (aluControl[2:0])
            `BEQ:  btaken = (a == b);
            `BNE:  btaken = (a != b);
            `BLT:  btaken = ($signed(a) < $signed(b));
            `BGE:  btaken = ($signed(a) >= $signed(b));
            `BLTU: btaken = (a < b);
            `BGEU: btaken = (a >= b);
        endcase
    end
endmodule
```

#### 3. Immediate Extender
```systemverilog
module immExtend (
    input  logic [31:0] instrCode,
    output logic [31:0] immExt
);
    wire [6:0] opcode = instrCode[6:0];
    
    always_comb begin
        case (opcode)
            // I-Type: imm[11:0]
            `OP_TYPE_I, `OP_TYPE_L: 
                immExt = {{20{instrCode[31]}}, instrCode[31:20]};
            
            // S-Type: imm[11:5] + imm[4:0]
            `OP_TYPE_S: 
                immExt = {{20{instrCode[31]}}, instrCode[31:25], instrCode[11:7]};
            
            // B-Type: imm[12,10:5,4:1,11,0]
            `OP_TYPE_B:
                immExt = {{20{instrCode[31]}}, instrCode[7], 
                          instrCode[30:25], instrCode[11:8], 1'b0};
            
            // U-Type: imm[31:12] + 12'b0
            `OP_TYPE_LU, `OP_TYPE_AU: 
                immExt = {instrCode[31:12], 12'b0};
            
            // J-Type: imm[20,10:1,11,19:12,0]
            `OP_TYPE_J:
                immExt = {{12{instrCode[31]}}, instrCode[19:12], 
                          instrCode[20], instrCode[30:21], 1'b0};
            
            default: immExt = 32'bx;
        endcase
    end
endmodule
```

#### 4. Pipeline Registers
```systemverilog
// Decode → Execute 사이
register U_DecReg_RFData1 (
    .clk  (clk),
    .reset(reset),
    .d    (RFData1),
    .q    (DecReg_RFData1)
);

register U_DecReg_RFData2 (
    .clk  (clk),
    .reset(reset),
    .d    (RFData2),
    .q    (DecReg_RFData2)
);

// Execute → Memory 사이
register U_ExeReg_ALU (
    .clk  (clk),
    .reset(reset),
    .d    (aluResult),
    .q    (ExeReg_aluResult)
);

// Memory → WriteBack 사이
register U_MemAccReg_ReadData (
    .clk  (clk),
    .reset(reset),
    .d    (busRData),
    .q    (MemAccReg_busRData)
);
```

### 📌 데이터 흐름 예시

#### 예시 1: ADD x3, x1, x2
```
Cycle 1 (FETCH):
  PC → ROM → instrCode = 0x002081B3
  PCEn = 1 → PC = PC + 4

Cycle 2 (DECODE):
  instrCode[6:0] = 0110011 (R-Type)
  rs1 = instrCode[19:15] = 1 (x1)
  rs2 = instrCode[24:20] = 2 (x2)
  rd  = instrCode[11:7]  = 3 (x3)
  
  RegFile[1] → RFData1 → DecReg_RFData1
  RegFile[2] → RFData2 → DecReg_RFData2

Cycle 3 (R_EXE):
  aluControl = ADD
  aluSrcMuxSel = 0 (rs2)
  
  ALU: DecReg_RFData1 + DecReg_RFData2 → aluResult
  regFileWe = 1
  
  RegFile[3] ← aluResult
```

#### 예시 2: LW x5, 0(x1)
```
Cycle 1 (FETCH):
  PC → ROM → instrCode = 0x0000A283
  PCEn = 1 → PC = PC + 4

Cycle 2 (DECODE):
  opcode = 0000011 (L-Type)
  rs1 = 1 (x1)
  rd  = 5 (x5)
  imm = 0
  
  RegFile[1] → RFData1 → DecReg_RFData1
  immExt = 0 → DecReg_immExt

Cycle 3 (L_EXE):
  aluControl = ADD
  aluSrcMuxSel = 1 (imm)
  
  ALU: DecReg_RFData1 + DecReg_immExt → aluResult
  aluResult → ExeReg_aluResult

Cycle 4 (L_MEM):
  busAddr = ExeReg_aluResult
  transfer = 1 → APB Master 시작
  
  APB: IDLE → SETUP → ACCESS
  busRData ← Memory[busAddr]
  
  busRData → MemAccReg_busRData

Cycle 5 (L_WB):
  RFWDSrcMuxSel = 001 (Memory data)
  regFileWe = 1
  
  RegFile[5] ← MemAccReg_busRData

Cycle 6 (MEMORY_DELAY):
  (대기)
```

---

# 4. APB 버스 프로토콜

## 4.1 APB (Advanced Peripheral Bus)

### 📌 APB란?
- **AMBA (Advanced Microcontroller Bus Architecture)** 계열
- **저속 Peripheral용** 버스
- **간단한 인터페이스**
- **0 또는 1 Wait State**

### 📌 AMBA 버스 계층

```
┌─────────────────────────────────────┐
│      AXI (고속, 고성능)              │  CPU ↔ Memory
├─────────────────────────────────────┤
│      AHB (중속, 중성능)              │  DMA, Bridge
├─────────────────────────────────────┤
│      APB (저속, 저전력)              │  UART, GPIO, Timer
└─────────────────────────────────────┘
```

### 📌 APB vs AXI4-Lite

| 항목 | APB | AXI4-Lite |
|------|-----|-----------|
| **채널** | 단일 | 5개 (분리) |
| **Handshake** | PSEL+PENABLE | VALID+READY |
| **복잡도** | 낮음 | 높음 |
| **성능** | 낮음 | 높음 |
| **용도** | 저속 Peripheral | 레지스터 접근 |

---

## 4.2 APB 신호

### 📌 APB Master 신호

| 신호 | 방향 | 설명 |
|------|------|------|
| **PCLK** | Input | 클럭 |
| **PRESET** | Input | 리셋 (Active High) |
| **PADDR[31:0]** | Output | 주소 |
| **PWRITE** | Output | 1=Write, 0=Read |
| **PSEL** | Output | Slave 선택 (Active High) |
| **PENABLE** | Output | Enable (2nd cycle) |
| **PWDATA[31:0]** | Output | Write 데이터 |
| **PRDATA[31:0]** | Input | Read 데이터 |
| **PREADY** | Input | Slave 준비 (0=Wait) |

### 📌 APB 주소 맵 (본 프로젝트)

| Peripheral | Base Address | 설명 |
|-----------|-------------|------|
| **RAM** | 0x10000000 | Data Memory |
| **GPO** | 0x10002000 | GPIO Output |
| **GPI** | 0x10002000 (미사용) | GPIO Input |
| **UART** | 0x10003000 | UART Peripheral |

**APB_Decoder 로직:**
```systemverilog
always_comb begin
    y = 4'b0000;
    if (en) begin
        casex (sel)
            32'h1000_0xxx: y = 4'b0001;  // PSEL0 (RAM)
            32'h1000_1xxx: y = 4'b0010;  // PSEL1 (Reserved)
            32'h1000_2xxx: y = 4'b0100;  // PSEL2 (GPO)
            32'h1000_3xxx: y = 4'b1000;  // PSEL3 (UART)
        endcase
    end
end
```

---

## 4.3 APB 상태 머신

### 📌 APB Master FSM

```
       ┌──────┐
       │ IDLE │  PSEL=0, PENABLE=0
       └───┬──┘
           │ transfer=1
           ↓
       ┌──────┐
       │SETUP │  PSEL=1, PENABLE=0, PADDR/PWRITE/PWDATA 유효
       └───┬──┘
           │ (무조건)
           ↓
       ┌──────┐
       │ACCESS│  PSEL=1, PENABLE=1
       └───┬──┘
           │ PREADY=1
           ↓
       ┌──────┐
       │ IDLE │
       └──────┘
```

### 📌 타이밍 다이어그램

```
PCLK:    ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
         ┘ └─┘ └─┘ └─┘ └─┘ └─

transfer:──┐   ┌───────────
           └───┘

State:   IDLE SETUP ACCESS IDLE

PSEL:    ───┐       ┌─────
            └───────┘

PENABLE: ───────┐   ┌─────
                └───┘

PADDR:   ────<ADDR >─────
PWRITE:  ────<WR   >─────
PWDATA:  ────<DATA >───── (Write일 때)

PREADY:  ───────────┐─────
                    └─────
```

### 📌 코드 분석: APB_Master.sv

```systemverilog
typedef enum {
    IDLE,
    SETUP,
    ACCESS
} apb_state_e;

apb_state_e state, state_next;

always_comb begin
    state_next = state;
    decoder_en = 1'b0;
    PENABLE = 1'b0;
    
    case (state)
        IDLE: begin
            decoder_en = 1'b0;
            if (transfer) begin
                state_next = SETUP;
                // 주소, 데이터, Write 신호 래치
                temp_addr_next = addr;
                temp_wdata_next = wdata;
                temp_write_next = write;
            end
        end
        
        SETUP: begin
            decoder_en = 1'b1;  // PSEL 활성화
            PENABLE = 1'b0;
            PADDR = temp_addr_reg;
            PWRITE = temp_write_reg;
            state_next = ACCESS;
            if (temp_write_reg) begin
                PWDATA = temp_wdata_reg;
            end
        end
        
        ACCESS: begin
            decoder_en = 1'b1;  // PSEL 유지
            PENABLE = 1'b1;     // PENABLE 활성화
            if (ready) begin    // Slave가 준비되면
                state_next = IDLE;
            end
        end
    endcase
end
```

---

# 5. Peripheral 설계

## 5.1 UART (Universal Asynchronous Receiver/Transmitter)

### 📌 UART 개요
- **비동기 직렬 통신**
- **Full-Duplex** (TX, RX 독립)
- **Baud Rate**: 9600, 115200 등
- **Frame**: Start bit + 8 data bits + Stop bit

### 📌 UART 프레임

```
Idle: ────┐                           ┌────
          └───┬───┬───┬───┬───┬───┬───┘
          Start D0  D1  D2  D3  D4  D5  Stop
            0   LSB                 MSB  1
```

### 📌 UART + FIFO 구조

```
┌──────────────────────────────────────┐
│          UART Peripheral             │
│                                       │
│  ┌────────┐   ┌────────┐   ┌──────┐ │
│  │ APB IF │──▶│TX FIFO │──▶│ TX   │──▶ uart_tx
│  └────────┘   └────────┘   │ Core │ │
│      │                      └──────┘ │
│      │        ┌────────┐   ┌──────┐ │
│      └───────▶│RX FIFO │◀──│ RX   │◀── uart_rx
│               └────────┘   │ Core │ │
│                            └──────┘ │
└──────────────────────────────────────┘
```

### 📌 UART 레지스터 맵

| Offset | Register | R/W | 설명 |
|--------|---------|-----|------|
| 0x00 | TX_DATA | W | 송신 데이터 (FIFO에 쓰기) |
| 0x04 | (예약) | - | - |
| 0x08 | STATUS | R | [1]: tx_fifo_full, [0]: rx_fifo_empty |
| 0x0C | RX_DATA | R | 수신 데이터 (FIFO에서 읽기) |

### 📌 UART 사용 예시 (C 코드)

```c
#define UART_BASE 0x10003000
#define UART_TX   (*(volatile uint32_t*)(UART_BASE + 0x00))
#define UART_STATUS (*(volatile uint32_t*)(UART_BASE + 0x08))
#define UART_RX   (*(volatile uint32_t*)(UART_BASE + 0x0C))

void uart_send_char(char c) {
    // TX FIFO가 꽉 찰 때까지 대기
    while (UART_STATUS & 0x02);  // tx_fifo_full
    UART_TX = c;
}

char uart_recv_char() {
    // RX FIFO가 비어있을 때까지 대기
    while (UART_STATUS & 0x01);  // rx_fifo_empty
    return UART_RX;
}

void uart_send_string(char* str) {
    while (*str) {
        uart_send_char(*str++);
    }
}

// 사용 예
int main() {
    uart_send_string("Hello, World!\n");
    
    char cmd[10];
    int i = 0;
    while (1) {
        cmd[i] = uart_recv_char();
        if (cmd[i] == '\n') {
            cmd[i] = '\0';
            if (strcmp(cmd, "ODD") == 0) {
                GPO = 0xAA;  // LED 홀수번만 켜기
            }
            i = 0;
        } else {
            i++;
        }
    }
}
```

---

## 5.2 GPIO (General Purpose Input/Output)

### 📌 GPO (Output)

```systemverilog
module GPO_Periph (
    input  logic        PCLK,
    input  logic        PRESET,
    input  logic [ 3:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic [ 7:0] gpo      // 외부 핀
);
    logic [31:0] gpo_reg;
    
    // APB Write
    always_ff @(posedge PCLK) begin
        if (PRESET) begin
            gpo_reg <= 32'b0;
        end else if (PSEL && PENABLE && PWRITE) begin
            if (PADDR[3:2] == 2'd0) begin
                gpo_reg <= PWDATA;
            end
        end
    end
    
    // 외부 핀 연결
    assign gpo = gpo_reg[7:0];
    
    // APB Read
    assign PRDATA = gpo_reg;
    
    // 0-wait state
    always_ff @(posedge PCLK) begin
        if (PRESET) PREADY <= 1'b0;
        else PREADY <= PSEL;
    end
endmodule
```

### 📌 GPI (Input)

```systemverilog
module GPI_Periph (
    input  logic        PCLK,
    input  logic        PRESET,
    input  logic [ 3:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    input  logic [ 7:0] gpi      // 외부 핀
);
    // GPI는 Read만 가능
    assign PRDATA = {24'b0, gpi};
    
    always_ff @(posedge PCLK) begin
        if (PRESET) PREADY <= 1'b0;
        else PREADY <= PSEL;
    end
endmodule
```

---

## 5.3 메모리 (ROM, RAM)

### 📌 ROM (Program Memory)

```systemverilog
module ROM (
    input  logic [31:0] addr,
    output logic [31:0] data
);
    logic [31:0] mem[0:2**12-1];  // 4KB
    
    initial begin
        $readmemh("code.mem", mem);  // Hex 파일 로드
    end
    
    assign data = mem[addr[13:2]];  // Word addressing
endmodule
```

### 📌 RAM (Data Memory)

```systemverilog
module RAM (
    input  logic        PCLK,
    input  logic        PRESET,
    input  logic [11:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY
);
    logic [31:0] mem[0:2**10-1];  // 1KB
    
    always_ff @(posedge PCLK) begin
        if (PSEL && PENABLE && PWRITE) begin
            mem[PADDR[11:2]] <= PWDATA;
        end
    end
    
    assign PRDATA = mem[PADDR[11:2]];
    
    always_ff @(posedge PCLK) begin
        if (PRESET) PREADY <= 1'b0;
        else PREADY <= PSEL;
    end
endmodule
```

---

# 6. 코드 상세 분석

## 6.1 명령어 실행 예시

### 📌 예시 1: ADDI x5, x0, 100
**의미:** x5 = x0 + 100 = 100

**Machine Code:**
```
0x06400293
= 0000 0110 0100 0000 0000 0010 1001 0011
  imm[11:0]  rs1   funct3  rd   opcode
  0x064      0     000     5    0010011
```

**실행 과정:**
```
Cycle 1 (FETCH):
  PC = 0x00000000
  ROM[0] → instrCode = 0x06400293
  PC ← PC + 4 = 0x00000004

Cycle 2 (DECODE):
  opcode = 0010011 → I-Type
  rs1 = 0, rd = 5
  imm = 0x064 (100)
  
  RegFile[0] = 0 → RFData1 → DecReg_RFData1 = 0
  immExt = 100 → DecReg_immExt = 100

Cycle 3 (I_EXE):
  aluControl = ADD
  aluSrcMuxSel = 1 (imm)
  
  ALU: 0 + 100 = 100
  regFileWe = 1
  
  RegFile[5] ← 100
```

### 📌 예시 2: SW x5, 0(x1)
**의미:** MEM[x1] = x5

**Machine Code:**
```
0x0050A023
= 0000 0000 0101 0000 1010 0000 0010 0011
  imm[11:5] rs2 rs1 funct3 imm[4:0] opcode
  0000000   5   1   010     00000  0100011
```

**실행 과정:**
```
Cycle 1 (FETCH):
  PC = 0x00000004
  ROM[1] → instrCode = 0x0050A023
  PC ← PC + 4 = 0x00000008

Cycle 2 (DECODE):
  opcode = 0100011 → S-Type
  rs1 = 1, rs2 = 5
  imm = 0
  
  RegFile[1] → RFData1 → DecReg_RFData1 (주소)
  RegFile[5] → RFData2 → DecReg_RFData2 (데이터)
  immExt = 0 → DecReg_immExt = 0

Cycle 3 (S_EXE):
  aluControl = ADD
  aluSrcMuxSel = 1 (imm)
  
  ALU: DecReg_RFData1 + 0 → aluResult (주소)
  aluResult → ExeReg_aluResult
  DecReg_RFData2 → ExeReg_RFData2

Cycle 4 (S_MEM):
  busAddr = ExeReg_aluResult
  busWData = ExeReg_RFData2
  busWe = 1
  transfer = 1
  
  APB Master: IDLE → SETUP

Cycle 5 (S_MEM, continued):
  APB Master: SETUP → ACCESS
  PSEL = 1, PENABLE = 1
  RAM[busAddr] ← busWData
  PREADY = 1 → ready = 1
  
  next_state = MEMORY_DELAY

Cycle 6 (MEMORY_DELAY):
  (대기)
  
  next_state = FETCH
```

### 📌 예시 3: BEQ x1, x2, label
**의미:** if (x1 == x2) PC = PC + offset

**Machine Code:**
```
0x00208463
= 0000 0000 0010 0000 1000 0100 0110 0011
  imm[12,10:5] rs2 rs1 funct3 imm[4:1,11] opcode
  0000000      2   1   000     01000      1100011
```

**실행 과정 (x1 == x2인 경우):**
```
Cycle 1 (FETCH):
  PC = 0x00000008
  ROM[2] → instrCode = 0x00208463
  PC ← PC + 4 = 0x0000000C

Cycle 2 (DECODE):
  opcode = 1100011 → B-Type
  rs1 = 1, rs2 = 2
  imm = 8 (label offset)
  
  RegFile[1] → RFData1 → DecReg_RFData1
  RegFile[2] → RFData2 → DecReg_RFData2
  immExt = 8 → DecReg_immExt = 8

Cycle 3 (B_EXE):
  aluControl = BEQ (000)
  branch = 1
  
  ALU: btaken = (DecReg_RFData1 == DecReg_RFData2) = 1
  
  PCSrcMuxSel = jal | (btaken & branch) = 0 | (1 & 1) = 1
  PC_Imm_AdderResult = PC + immExt = 0x08 + 8 = 0x10
  
  PCSrcMux: x1 선택 → PC_Imm_AdderResult
  PC ← 0x10 (label 위치로 점프!)
```

---

## 6.2 어셈블리 → Machine Code 변환

### 📌 예시 프로그램

```assembly
# LED Blink Program
# GPO base: 0x10002000

    addi x1, x0, 0xAA      # x1 = 0xAA (LED pattern)
    lui  x2, 0x10002       # x2 = 0x10002000 (GPO base)
loop:
    sw   x1, 0(x2)         # GPO[0] = x1 (LED ON)
    addi x3, x0, 1000000   # x3 = 1000000 (delay count)
delay:
    addi x3, x3, -1        # x3--
    bne  x3, x0, delay     # if (x3 != 0) goto delay
    
    sw   x0, 0(x2)         # GPO[0] = 0 (LED OFF)
    addi x3, x0, 1000000   # x3 = 1000000
delay2:
    addi x3, x3, -1        # x3--
    bne  x3, x0, delay2    # if (x3 != 0) goto delay2
    
    jal  x0, loop          # goto loop
```

### 📌 Machine Code (code.mem)

```
0AA00093  // addi x1, x0, 0xAA
10002137  // lui  x2, 0x10002
00112023  // sw   x1, 0(x2)
0F42A193  // addi x3, x0, 1000000
FFF18193  // addi x3, x3, -1
FE019CE3  // bne  x3, x0, delay
00012023  // sw   x0, 0(x2)
0F42A193  // addi x3, x0, 1000000
FFF18193  // addi x3, x3, -1
FE019CE3  // bne  x3, x0, delay2
FE9FF06F  // jal  x0, loop
```

---

# 7. Trouble Shooting

## 7.1 문제 상황 1: UART ODD 명령 인식 실패

### 📌 문제
**UART로 "ODD" 명령을 연속 입력 시, 문자열을 한 번에 인식하지 못해 LED 제어가 정상 동작하지 않음**

**증상:**
```
User Input: "ODD\n"
Expected: LED 패턴 0xAA (홀수번 LED만 켜짐)
Actual: 반응 없음 또는 이상한 동작
```

### 📌 원인 분석

**UART 수신 특성:**
- UART는 **문자 단위**로 수신
- "ODD\n"은 4개 문자: 'O', 'D', 'D', '\n'
- 각 문자는 **순차적으로** 도착

**초기 코드 (문제):**
```c
char cmd[10];
int main() {
    while (1) {
        char c = uart_recv_char();
        if (c == 'O') {
            // 'O'만 받고 바로 비교?
            if (strcmp(cmd, "ODD") == 0) {  // ❌ 아직 "ODD"가 안 왔음!
                GPO = 0xAA;
            }
        }
    }
}
```

**문제점:**
1. 'O' 받자마자 strcmp 호출 → 'D', 'D'는 아직 안 받음
2. 문자열 버퍼링 없음
3. 상태 추적 없음

### 📌 해결 방법

**문자 스트림 특성을 고려해 O → O·D → D를 순차 인식하는 상태 기반 파싱 로직 적용**

#### 방법 1: 버퍼링 + '\n' 대기
```c
char cmd[10];
int idx = 0;

int main() {
    while (1) {
        char c = uart_recv_char();
        
        if (c == '\n' || c == '\r') {
            // 문자열 완성!
            cmd[idx] = '\0';  // NULL terminator
            
            // 명령어 비교
            if (strcmp(cmd, "ODD") == 0) {
                GPO = 0xAA;  // ✅ 홀수 LED
            } else if (strcmp(cmd, "ALL") == 0) {
                GPO = 0xFF;  // ✅ 모든 LED
            } else if (strcmp(cmd, "OFF") == 0) {
                GPO = 0x00;  // ✅ 모든 LED OFF
            }
            
            idx = 0;  // 버퍼 초기화
        } else {
            // 문자 누적
            cmd[idx++] = c;
        }
    }
}
```

#### 방법 2: FSM 기반 파싱 (더 효율적)
```c
typedef enum {
    STATE_IDLE,
    STATE_O,
    STATE_OD,
    STATE_ODD
} parse_state_e;

parse_state_e state = STATE_IDLE;

int main() {
    while (1) {
        char c = uart_recv_char();
        
        switch (state) {
            case STATE_IDLE:
                if (c == 'O') state = STATE_O;
                else if (c == 'A') /* ... */;
                break;
            
            case STATE_O:
                if (c == 'D') state = STATE_OD;
                else state = STATE_IDLE;
                break;
            
            case STATE_OD:
                if (c == 'D') state = STATE_ODD;
                else state = STATE_IDLE;
                break;
            
            case STATE_ODD:
                // 완성!
                GPO = 0xAA;
                state = STATE_IDLE;
                break;
        }
    }
}
```

**FSM 다이어그램:**
```
        'O'         'D'         'D'
IDLE ───────▶ O ───────▶ OD ───────▶ ODD ──┐
  ▲           │          │              │  │
  │           │ (other)  │ (other)      │  │
  └───────────┴──────────┴──────────────┘  │
                                            │
                                            │ (완성)
                                            ▼
                                        GPO = 0xAA
```

### 📌 검증 결과

**수정 전:**
```
Input: "ODD"
Result: 반응 없음
Success Rate: 0%
```

**수정 후:**
```
Input: "ODD"
Result: LED[1,3,5,7] ON (0xAA)
Success Rate: 100%
```

---

## 7.2 문제 상황 2: Memory Access 타이밍 충돌

### 📌 문제
**S-Type (Store) 또는 L-Type (Load) 명령 실행 후 바로 FETCH로 가면 APB 버스 충돌 발생**

**증상:**
```
Error: APB Master still in ACCESS state when new FETCH starts
Result: Instruction fetch fails
```

### 📌 원인 분석

**APB 타이밍:**
```
Cycle N:   IDLE
Cycle N+1: SETUP  (PSEL=1, PENABLE=0)
Cycle N+2: ACCESS (PSEL=1, PENABLE=1, PREADY=1)
           ↑
         여기서 전송 완료
```

**초기 FSM (문제):**
```
S_MEM → (ready=1) → FETCH  ❌
                     ↑
                   충돌!
                   FETCH도 Memory 접근 필요
```

### 📌 해결 방법

**MEMORY_DELAY 상태 추가로 1 cycle 대기**

```
S_MEM → (ready=1) → MEMORY_DELAY → FETCH  ✅
L_WB  → (always)  → MEMORY_DELAY → FETCH  ✅
```

**코드:**
```systemverilog
// ControlUnit.sv
always_comb begin
    case (state)
        S_MEM:  if (ready) next_state = MEMORY_DELAY;
        L_WB:   next_state = MEMORY_DELAY;
        MEMORY_DELAY: next_state = FETCH;
    endcase
end
```

**타이밍:**
```
Cycle N:   S_MEM      (APB: ACCESS, PREADY=1)
Cycle N+1: MEMORY_DELAY (대기)
Cycle N+2: FETCH      (새로운 명령어 가져오기)
```

---

# 8. 면접 예상 질문 & 답변

## 8.1 프로젝트 전반

### Q1: 이 프로젝트를 한 이유는?
**답변:**
"RISC-V는 오픈소스 ISA로 최근 산업계에서 주목받고 있어 직접 구현해보고 싶었습니다. Multi-Cycle 설계를 통해 FSM 설계 경험을 쌓고, APB 버스 프로토콜로 실제 SoC 구조를 이해하며, UART 통신으로 Peripheral 제어까지 경험하고 싶었습니다. 특히 FPGA에서 실제 동작을 확인하여 이론과 실습을 모두 경험했습니다."

### Q2: 가장 어려웠던 점은?
**답변:**
"두 가지가 어려웠습니다. 첫째, UART 명령어 파싱 문제입니다. 'ODD' 같은 문자열을 순차적으로 수신하는 특성을 고려하지 못해 초기에는 명령 인식에 실패했습니다. 버퍼링과 FSM 기반 파싱으로 해결했습니다. 둘째, Memory Access 후 타이밍 충돌 문제입니다. APB 버스가 2 cycle 필요한데 바로 FETCH로 가면 충돌이 발생했습니다. MEMORY_DELAY 상태를 추가해 해결했습니다."

### Q3: Single-Cycle 대신 Multi-Cycle을 선택한 이유는?
**답변:**
"교육 목적으로 FSM 설계 경험을 쌓기 위해서였고, Pipeline Hazard 없이 명확한 동작을 이해하고 싶었습니다. 또한 Multi-Cycle은 클럭 속도를 높일 수 있고, 리소스(ALU, Memory)를 재사용해 효율적입니다. Pipelined 버전도 고려했지만, Hazard Detection과 Forwarding 로직의 복잡도 때문에 먼저 Multi-Cycle로 시작했습니다."

---

## 8.2 RISC-V 관련

### Q4: RISC-V RV32I의 37개 명령어를 설명하세요.
**답변:**
"RV32I는 32-bit Integer Base ISA로 37개 명령어를 지원합니다:
- **R-Type (10개)**: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
- **I-Type (13개)**: ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU, LB, LH, LW, LBU, LHU
- **S-Type (3개)**: SB, SH, SW
- **B-Type (6개)**: BEQ, BNE, BLT, BGE, BLTU, BGEU
- **U-Type (2개)**: LUI, AUIPC
- **J-Type (2개)**: JAL, JALR

각 명령어는 opcode, funct3, funct7로 구분되며, 본 프로젝트에서 모두 구현했습니다."

### Q5: x0 레지스터가 특별한 이유는?
**답변:**
"x0는 항상 0으로 하드와이어드되어 있어 어떤 값을 써도 0으로 유지됩니다. 이는 RISC-V의 설계 철학으로, 상수 0을 자주 사용하기 때문에 효율성을 위해 도입되었습니다. 예를 들어 `addi x1, x0, 100`은 x1에 100을 로드하는 효과를 내며, `beq x1, x0, label`은 x1이 0인지 확인하는 용도로 사용됩니다."

### Q6: Immediate 값이 명령어마다 다른 이유는?
**답변:**
"32-bit 명령어 포맷에서 opcode, rs1, rs2, rd를 제외한 나머지 비트를 immediate로 사용하기 때문입니다:
- **I-Type**: 12-bit (imm[11:0])
- **S-Type**: 12-bit (imm[11:5] + imm[4:0])
- **B-Type**: 13-bit (imm[12,10:5,4:1,11], LSB=0)
- **U-Type**: 20-bit (imm[31:12], 하위 12bit=0)
- **J-Type**: 21-bit (imm[20,10:1,11,19:12], LSB=0)

각 타입마다 필요한 비트 수와 사용 목적이 다르기 때문에 포맷이 다릅니다."

---

## 8.3 Multi-Cycle 관련

### Q7: Multi-Cycle FSM의 15개 상태를 설명하세요.
**답변:**
"Control Unit은 15개 상태로 구성됩니다:
1. **FETCH**: 명령어 가져오기, PC 업데이트
2. **DECODE**: Opcode 해석, Register File 읽기
3-9. **Execute States**: R_EXE, I_EXE, B_EXE, LU_EXE, AU_EXE, J_EXE, JL_EXE
10-11. **Store**: S_EXE (주소 계산), S_MEM (메모리 쓰기)
12-14. **Load**: L_EXE (주소 계산), L_MEM (메모리 읽기), L_WB (Write Back)
15. **MEMORY_DELAY**: Memory Access 후 대기

대부분 명령어는 3 cycles에 완료되지만, Store는 5 cycles, Load는 6 cycles가 필요합니다."

### Q8: 왜 Load가 Store보다 1 cycle 더 필요한가요?
**답변:**
"Load는 메모리에서 데이터를 읽은 후 Register File에 쓰는 Write Back 단계가 필요하기 때문입니다:

**Store:**
- S_EXE: 주소 계산
- S_MEM: 메모리 쓰기 (끝)

**Load:**
- L_EXE: 주소 계산
- L_MEM: 메모리 읽기
- L_WB: Register File에 쓰기 (1 cycle 추가)

Store는 메모리에 쓰기만 하면 끝이지만, Load는 읽은 데이터를 레지스터에 저장해야 하므로 1 cycle이 더 필요합니다."

### Q9: Pipeline Register의 역할은?
**답변:**
"Pipeline Register (DecReg, ExeReg, MemAccReg)는 각 단계의 결과를 저장하여 다음 단계로 전달합니다. Multi-Cycle에서는 명령어가 여러 cycle에 걸쳐 실행되므로, 중간 결과를 저장할 레지스터가 필요합니다. 예를 들어:
- **DecReg**: Decode 단계에서 읽은 Register 값, Immediate 값 저장
- **ExeReg**: Execute 단계에서 계산한 ALU 결과 저장
- **MemAccReg**: Memory Access 단계에서 읽은 데이터 저장

이를 통해 각 단계가 독립적으로 동작할 수 있습니다."

---

## 8.4 APB 관련

### Q10: APB와 AXI의 차이는?
**답변:**

| 항목 | APB | AXI4-Lite |
|------|-----|-----------|
| **채널** | 단일 | 5개 (분리) |
| **Handshake** | PSEL+PENABLE | VALID+READY |
| **복잡도** | 낮음 | 높음 |
| **성능** | 낮음 (Wait State) | 높음 (병렬) |
| **용도** | 저속 Peripheral | 레지스터 접근 |

APB는 간단하고 전력 소모가 적어 UART, GPIO 같은 저속 Peripheral에 적합합니다. AXI는 고성능이 필요한 메모리 접근에 사용됩니다."

### Q11: APB 3-state FSM을 설명하세요.
**답변:**
"APB Master는 3개 상태로 동작합니다:

1. **IDLE**: 대기 상태, PSEL=0, PENABLE=0
2. **SETUP**: 주소/데이터 설정, PSEL=1, PENABLE=0
3. **ACCESS**: 실제 전송, PSEL=1, PENABLE=1

IDLE에서 transfer 신호가 오면 SETUP으로 가고, 1 cycle 후 무조건 ACCESS로 갑니다. ACCESS에서 PREADY=1이면 전송 완료 후 IDLE로 돌아갑니다. 최소 2 cycles가 필요합니다."

### Q12: PREADY의 역할은?
**답변:**
"PREADY는 Slave가 준비되었음을 알리는 신호입니다. PREADY=0이면 Slave가 아직 처리 중이므로 Master는 ACCESS 상태에서 대기합니다 (Wait State). 본 프로젝트에서는 RAM, UART, GPO 모두 1 cycle에 응답하도록 설계했기 때문에 PREADY는 항상 1입니다. 만약 느린 Peripheral이 있다면 PREADY=0으로 대기시킬 수 있습니다."

---

## 8.5 UART 관련

### Q13: UART의 Baud Rate는 어떻게 결정되나요?
**답변:**
"Baud Rate는 초당 전송 비트 수입니다. 본 프로젝트에서는 9600 bps를 사용했습니다. 클럭 Divider로 생성합니다:

```
Baud Rate = System Clock / (Divider * 16)
9600 = 100MHz / (Divider * 16)
Divider = 100,000,000 / (9600 * 16) ≈ 651
```

16x oversampling을 사용해 수신 타이밍 정확도를 높입니다."

### Q14: FIFO가 왜 필요한가요?
**답변:**
"UART는 비동기 통신이라 송수신 속도 차이가 발생할 수 있습니다. CPU가 바쁘거나 다른 작업 중일 때 UART 데이터가 들어오면 놓칠 수 있습니다. FIFO는 이런 데이터를 임시 저장해 손실을 방지합니다. TX FIFO는 송신 데이터를 버퍼링하고, RX FIFO는 수신 데이터를 저장해 CPU가 나중에 읽을 수 있게 합니다."

### Q15: UART Frame 구조를 설명하세요.
**답변:**
"UART는 비동기 통신으로 클럭 신호가 없기 때문에 Start/Stop bit로 동기화합니다:

```
Idle(1) → Start(0) → D0 D1 D2 D3 D4 D5 D6 D7 → Stop(1) → Idle(1)
          ↑ LSB first                   MSB ↑
```

- **Idle**: 평소에는 High
- **Start bit**: 0으로 떨어지면 시작
- **8 data bits**: LSB first
- **Stop bit**: 1로 올라가면 끝

Parity bit는 생략했습니다 (8N1 설정)."

---

## 8.6 고급 질문

### Q16: 만약 Pipeline으로 확장한다면?
**답변:**
"5-stage Pipeline (IF-ID-EX-MEM-WB)으로 확장할 수 있습니다:

**추가 필요 사항:**
1. **Hazard Detection**: Data Hazard, Control Hazard 감지
2. **Forwarding Unit**: EX/MEM, MEM/WB에서 결과 전달
3. **Stall Logic**: Load-Use Hazard 시 1 cycle 대기
4. **Branch Prediction**: 분기 예측으로 성능 향상

**예상 성능:**
- CPI: 1에 가까워짐 (이상적)
- 클럭: 각 단계가 짧아져 더 빠른 클럭 가능
- 처리량: Multi-Cycle 대비 3~5배 향상

**Trade-off:**
- 복잡도 증가
- 디버깅 어려움
- 리소스 증가"

### Q17: Cache를 추가한다면?
**답변:**
"Instruction Cache와 Data Cache를 추가할 수 있습니다:

**I-Cache:**
- FETCH 단계에 추가
- Hit: 1 cycle
- Miss: Memory에서 Block 로드 (수십 cycle)

**D-Cache:**
- L_MEM, S_MEM 단계에 추가
- Write Policy: Write-Through or Write-Back

**기대 효과:**
- 평균 Memory Access Time 감소
- CPI 개선

**구현 복잡도:**
- Valid/Tag/Data Array
- Replacement Policy (LRU, Random)
- Coherency (Multi-Core 시)"

### Q18: 인터럽트를 구현한다면?
**답변:**
"RISC-V는 Machine Mode Interrupt를 지원합니다:

**필요 CSR (Control and Status Register):**
- **mtvec**: Interrupt Vector Table 주소
- **mepc**: Exception PC
- **mcause**: Interrupt 원인
- **mstatus**: Interrupt Enable

**구현:**
1. Peripheral에서 IRQ 신호 생성 (UART_RX, Timer)
2. Control Unit에서 IRQ 감지
3. 현재 PC를 mepc에 저장
4. PC ← mtvec (Interrupt Handler)
5. Handler 실행 후 MRET 명령으로 복귀

**장점:**
- Polling 대신 Interrupt로 효율성 향상
- 실시간 응답 가능"

---

## 8.7 실무 관련

### Q19: 실무에서 이런 CPU를 어디에 사용하나요?
**답변:**
"RISC-V는 다양한 분야에서 사용됩니다:

**IoT:**
- 센서 노드
- 스마트 홈 기기
- Wearable

**Embedded Systems:**
- 자동차 (ADAS)
- 산업 제어
- 의료 기기

**고성능:**
- 서버 (SiFive)
- AI 가속기
- HPC (High-Performance Computing)

본 프로젝트는 교육용이지만, 실제 제품에서는 Cache, Pipeline, Interrupt 등이 추가되고, Linux를 실행할 수 있는 RV64G (64-bit + Extensions) 버전이 사용됩니다."

### Q20: 이 프로젝트를 통해 배운 점은?
**답변:**
"세 가지를 배웠습니다:

1. **ISA 이해**: 명령어가 어떻게 하드웨어로 구현되는지 깊이 이해. 특히 Immediate Encoding, Register File, ALU 동작 원리

2. **FSM 설계**: Multi-Cycle FSM으로 복잡한 시스템을 상태 기반으로 설계하는 방법. Trouble Shooting으로 타이밍 문제 해결 능력 향상

3. **버스 프로토콜**: APB 버스로 CPU와 Peripheral 간 통신 구조 이해. 실제 SoC 설계의 기초

이를 통해 디지털 시스템 설계의 전체 흐름 (ISA → RTL → 검증 → FPGA)을 경험했고, 실무에 즉시 적용 가능한 역량을 갖추게 되었습니다."

---

## 9. 추가 학습 자료

### 📚 추천 서적
1. **"Computer Organization and Design RISC-V Edition"** - Patterson & Hennessy
2. **"Digital Design and Computer Architecture RISC-V Edition"** - Harris & Harris
3. **"The RISC-V Reader"** - Patterson & Waterman

### 🔗 추천 리소스
1. **RISC-V Official**: https://riscv.org/
2. **RISC-V ISA Manual**: https://riscv.org/technical/specifications/
3. **ARM AMBA Specification**: https://developer.arm.com/architectures/system-architectures/amba

### 💡 실습 과제
1. **Pipeline 구현**: 5-stage Pipeline + Hazard Detection
2. **Cache 추가**: I-Cache, D-Cache
3. **Interrupt**: Timer Interrupt 구현
4. **Extensions**: M Extension (Multiply/Divide)

---

## 10. 마무리

### ✅ 핵심 강조 포인트 (면접 시)

1. **"RISC-V RV32I 37개 명령어 모두 구현"**
   - R, I, S, L, B, U, J-Type

2. **"Multi-Cycle FSM 15개 상태"**
   - FETCH-DECODE-EXECUTE 흐름

3. **"APB 버스 프로토콜 Master/Slave"**
   - 3-state FSM (IDLE-SETUP-ACCESS)

4. **"Trouble Shooting 경험"**
   - UART 파싱 문제, Memory 타이밍 충돌

5. **"FPGA 실제 동작 검증"**
   - LED 제어, UART 통신

### 💪 자신감 있게 말하기
- "37개 명령어를 모두 구현했고, FPGA에서 실제로 LED를 제어하며 동작을 확인했습니다"
- "Multi-Cycle FSM 설계로 평균 3.5 CPI를 달성했고, 메모리 타이밍 문제를 MEMORY_DELAY 상태로 해결했습니다"
- "APB 버스로 UART, GPIO를 제어하는 완전한 SoC를 구현했습니다"

### 🎯 면접 팁
1. **구체적인 숫자** 사용 (37개, 15 states, 3.5 CPI)
2. **문제 해결 과정** 강조
3. **실제 동작** 언급 (FPGA, LED, UART)
4. **추가 질문** 유도 (Pipeline, Cache, Interrupt)

---

**면접 파이팅! 🚀**
