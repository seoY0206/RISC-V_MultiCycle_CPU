# RISC-V_MultiCycle_CPU

## Overview
RV32I 기반 Multi-Cycle CPU를 설계하고,
APB BUS를 통해 UART Peripheral을 제어하는 SoC 구조를 구현한 프로젝트.

## Tool & Language
- SystemVerilog
- FPGA (Basys3)

## Architecture
- Multi-Cycle FSM (Fetch / Decode / Execute)
- APB Master
- UART Peripheral

## Verification & Performance
- RV32I 37개 명령어 전수 테스트 PASS
- CPU → APB → UART → LED 제어 End-to-End 검증
- Multi-Cycle 구조로 자원 효율 확보

## Key Features
- UART 명령(ODD/ EVEN / ALL / OFF)에 따른 LED 제어
- 실제 FPGA 환경에서 동작 검증
