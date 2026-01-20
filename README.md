# BLE Flutter Mobile Application

This project is a Flutter-based mobile application implementing a complete Bluetooth Low Energy (BLE) workflow - from device discovery and connection management to data exchange and communication diagnostics. The application was developed by a four-person team with a clear division of responsibilities and development stages, resulting in a clean and extensible architecture.

## Project Overview

The application demonstrates a practical approach to integrating BLE communication into a mobile app while maintaining strict separation between the UI layer and communication logic. The design follows principles commonly used in embedded systems, where higher layers interact with hardware through well-defined interfaces instead of protocol-specific details.

## Architecture and Development Stages

### Stage 1 - Application Architecture and Core Setup

At the initial stage, the overall structure and navigation flow of the application were defined. The project was organized to separate UI components from BLE logic. Screens were designed to be lightweight and state-driven, while all BLE-related operations were delegated to a dedicated manager. This ensured a stable foundation for further development and simplified testing and maintenance.

### Stage 2 - Bluetooth Low Energy Management

A central BLE manager module was implemented to handle scanning, device discovery, connection lifecycle management, and basic data exchange. This module serves as the single point of interaction with the BLE stack, encapsulating platform-specific details and exposing a clean, consistent API to the UI layer.

### Stage 3 - User Interface and Screen Responsibilities

The application consists of three main screens, each with a clearly defined role:

- **Device List Screen**  
  Responsible for initiating BLE scans and displaying discovered devices in real time. It reflects scanning state and device availability without embedding communication logic.

- **Device Control Screen**  
  Manages the connection lifecycle (connect and disconnect) and provides a control interface for sending commands to the selected device. User actions are mapped to BLE operations via the manager layer.

- **Logs Screen**  
  Displays a chronological view of BLE events and data exchange. This screen acts as a diagnostic tool, enabling analysis of communication flow and simplifying debugging on both the application and firmware sides.

Each screen is implemented as an independent component, allowing future extensions or refactoring with minimal impact on the rest of the application.

### Stage 4 - Diagnostics and Maintainability

The final stage focused on improving code clarity, consistency, and observability. A structured logging mechanism was introduced to provide insight into BLE operations, effectively acting as a software-level logic analyzer for communication. The resulting architecture is ready for extension with additional BLE services, characteristics, or advanced application logic.
