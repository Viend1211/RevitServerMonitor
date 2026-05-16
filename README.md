# RevitServerMonitor

Advanced monitoring and diagnostic tool for Autodesk Revit Server.

## Features

- Revit Server configuration scan
- Detects `maxBytesPerRead` values
- Revit Server service health monitoring
- Error log analysis
- IIS error detection
- Synchronization tracking
- Model inventory
- Largest model analysis
- Last sync detection
- Last error detection
- HTML dashboard report generation
- Multi-version Revit Server support
- Portable EXE support

---

## Why?

Large Revit Server environments often suffer from:

- slow synchronization
- unstable model loading
- IIS timeout errors
- replication failures
- oversized models
- hidden synchronization issues

This tool helps administrators quickly diagnose and monitor Revit Server environments.

---

## Supported Versions

- Revit Server 2020
- Revit Server 2021
- Revit Server 2022
- Revit Server 2023
- Revit Server 2024
- Revit Server 2025

---

## What the tool scans

### Revit Server Configuration

- `maxBytesPerRead`
- Revit Server versions
- service states

### Logs

- ERROR
- FAILED
- EXCEPTION
- CRITICAL
- TIMEOUT
- IIS 500/503

### Models

- model size
- model paths
- last modified date
- largest models
- last synchronization events
- last related errors

---

## HTML Report

The tool generates a detailed HTML dashboard report including:

- server health
- configuration values
- detected errors
- model statistics
- synchronization activity
- service monitoring

---

## Usage

Run:
powershell -ExecutionPolicy Bypass -File .\RevitServerMonitor.ps1
