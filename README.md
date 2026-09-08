# Nested Sheet Assist for Vectric VCarve Pro & Aspire

[![Vectric V12+](https://img.shields.io/badge/Vectric-VCarve%20Pro%20%7C%20Aspire%20v12%2B-blue.svg)](https://www.vectric.com)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6.svg)](https://www.microsoft.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/badge/Release-v1.0.0-brightgreen.svg)](https://github.com/Th3-Future/Nested-Sheet-Assist/releases)

A high-performance productivity gadget for **Vectric VCarve Pro & Aspire (v12.0 / v12.5+)** that solves the major workflow hurdles when working with multi-sheet nested jobs:

1. **Automated Toolpath Synchronization from Active / Visible Operations**: Automatically copies and applies visible toolpaths calculated on any selected sheet across all other nested sheets in the job without needing a saved template file.
2. **Automated Toolpath Synchronization via Toolpath Templates (`.vtpt`)**: Automatically loads an external toolpath template file (`.vtpt`) and distributes/recalculates toolpaths across every nested sheet in the job (surpassing standard VCarve's limitation of only applying templates to the active sheet).
3. **Batch ATC NC File Export**: Automatically detects toolpaths on each sheet and exports separate, organized, machine-ready G-code/NC files per sheet using your active ATC Post Processor (`<JobName> - <SheetName>.<ext>`).
4. **Multi-Sheet Job Setup Sheet PDF Compiler**: Compiles an interactive, unified multi-page vector PDF report for **all sheets** or **selected sheets** only, with maximized part visibility on Page 1 (90vh) and clean toolpath specifications on Page 2 (zero orphan/empty pages).

---

## Core Features

### 1. Toolpath Synchronization from Active / Visible Operations
When you have already configured or previewed toolpaths on a specific sheet (e.g. Sheet 1), you can check **"Use Toolpath on Active Sheet"** and **"Only Visible Toolpaths"**. Nested Sheet Assist automatically propagates and recalculates those exact operations across all other nested sheets in the job in a single click.

### 2. Toolpath Synchronization via Toolpath Templates (`.vtpt`)
In standard Vectric software, loading a toolpath template (`.vtpt`) only applies toolpaths to the currently active sheet. **Nested Sheet Assist** iterates across all sheets, activates each sheet context in sequence, loads your toolpath template, and recalculates all toolpaths across the entire job automatically.

### 3. Batch ATC NC File Export
- Automatically detects and organizes toolpaths associated with each individual sheet.
- Saves separate machine-ready NC/TAP files per sheet directly to your designated output directory in one pass.
- Formatted naming: `<JobName> - <SheetName>.<ext>` (e.g. `Cabinet_Job - Sheet 1.tap`, `Cabinet_Job - Sheet 2.tap`).

### 4. High-Quality Multi-Sheet Setup Sheet PDF Generator
- **Interactive Sheet Selector**: Choose **Export All Sheets** or select specific sheets using an inline multi-select drawer.
- **Instant Selective Processing**: Hooks into the sheet evaluation engine to immediately bypass unselected sheets, avoiding unnecessary vector calculations and rendering only the requested sheets in seconds.
- **Optimized Layout**:
  - **Page 1**: Clean header with logo and a **maximized full-page Job Layout drawing (90vh)** for maximum part label and cut geometry visibility with minimal bottom whitespace.
  - **Page 2**: Material setup summary and individual toolpath specifications (feed rate, plunge, spindle speed, tool numbers, notes).
  - **Zero Orphan Pages**: Clean CSS break rules eliminate trailing footer splits and blank pages.
- **Fast Headless PDF Conversion**: Leverages Windows built-in Microsoft Edge headless printing engine for vector-crisp, multi-page PDF output.

---

## Requirements

- **Vectric Software**: VCarve Pro or Aspire **v12.0** or **v12.5+**
- **Operating System**: Windows 10 / 11
- **PDF Engine**: Microsoft Edge (pre-installed on Windows 10/11)

---

## Installation

1. Download the latest **`Nested_Sheet_Assist.vgadget`** from the [Releases](https://github.com/Th3-Future/Nested-Sheet-Assist/releases) page.
2. In VCarve Pro or Aspire, click **Gadgets** > **Install Gadget...** and select the downloaded file.
3. Restart VCarve Pro / Aspire (or press `Ctrl + F2`).
4. You will find **Nested Sheet Assist** under the **Gadgets** menu.

---

## Usage

1. Open a job with nested sheets and calculated vectors.
2. Launch **Gadgets > Nested Sheet Assist**.
3. **Configure Options**:
   - **Toolpath Template**: Select your `.vtpt` template file (optional if using active sheet toolpaths).
   - **Use Toolpaths on Active Sheet**: Check to synchronize operations directly from the current sheet.
   - **Only Visible Toolpaths**: Check to only synchronize toolpaths currently checked visible in the toolpath tree.
   - **Output Folder**: Select the destination folder for NC files and PDF reports.
   - **Post Processor**: Select your CNC machine's ATC post processor.
4. **Choose Action**:
   - **Apply & Save**: Synchronizes toolpaths across all sheets and exports NC files in one go.
   - **Apply Only**: Recalculates toolpaths on all sheets without exporting files.
   - **Save Only**: Exports separate NC files for all sheets using already calculated toolpaths.
   - **Export Job Report (PDF)**: Compiles the vector PDF report for all or selected sheets.

---

## Building from Source

To package the gadget from source:
```powershell
# Run the included build script
powershell -ExecutionPolicy Bypass -File .\build.ps1
```
This will generate `Nested_Sheet_Assist.vgadget` in the root directory.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author & Acknowledgements

- **Lead Developer**: **Godswill Ezeorah** ([@Th3-Future](https://github.com/Th3-Future))
- **AI Pair Programming & Architecture Assistance**: Developed with the assistance of **Antigravity** (Google DeepMind).
