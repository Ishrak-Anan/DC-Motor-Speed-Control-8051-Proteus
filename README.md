# DC Motor Speed Control System using 8051 Microcontroller

## Overview

This project implements an embedded DC motor control system using an AT89C51 (8051) microcontroller. The system provides keypad-based speed and direction control with LCD monitoring and PWM-based motor speed regulation.

The complete design was developed and simulated in Proteus.

## Implemented Features

- Clockwise (CW) motor rotation control
- Counter-clockwise (CCW) motor rotation control
- Keypad-based user commands
- PWM speed control
- 16x2 LCD status monitoring
- LED-based indication
- Acceleration monitoring
- Overheat protection and safety handling

## Hardware Components

- AT89C51 Microcontroller
- L293D Motor Driver
- DC Motor
- 16x2 LCD
- 4x4 Keypad
- LEDs
- Crystal oscillator

## Software Tools

- Proteus Design Suite
- 8051 Assembly Language

## Repository Structure

```
DC-Motor-Speed-Control-Proteus/

├── Proteus/
│   └── Proteus simulation files

├── 8051_Code/
│   ├── Assembly source
│   ├── HEX firmware
│   └── Listing file

├── Figures/
│   └── Simulation screenshots

└── Documentation/
    └── Project report
```

## Running the Simulation

1. Open the Proteus project file.
2. Load the provided HEX file into the AT89C51 if required.
3. Start simulation.
4. Use the keypad to test:
   - speed changes
   - direction changes
   - stop command
   - safety conditions

## Simulation Evidence

The Figures folder contains:
- Complete Proteus circuit
- LCD output states
- Motor driver section
- Control flow diagrams
- Safety operation demonstrations



## Portfolio Preview

The Figures folder contains actual Proteus simulation evidence including:
- complete circuit implementation
- LCD operating states
- motor driver interface
- safety handling demonstration
- software control flow diagrams
