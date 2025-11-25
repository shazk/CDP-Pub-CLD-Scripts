# 🚀 Cloudera on Cloud Automation Hub (CCAH)

The **Cloudera on Cloud Automation Hub (CCAH)** is an end-to-end automation toolkit designed for Cloudera CDP Public Cloud operations.  
It helps CloudOps, DevOps, and Big Data engineers automate common workflows such as:

- Data Lake Start/Stop
- DataHub Start/Stop/Status
- Backup & Restore status monitoring
- Host & cluster reporting
- API/CLI-driven checks and validations

This toolkit is built using **Shell scripts + Python modules**, and integrates directly with **CDP CLI** for seamless public cloud operations.

---

## 🔥 Features

### ✔ Data Lake Operations
- Start Data Lake  
- Stop Data Lake  
- Datalake health/status check

### ✔ DataHub Operations
- Start all DataHub clusters  
- Stop clusters  
- Cluster status/health check  
- Host information retrieval

### ✔ Backup Operations
- Fetch latest backup job status  
- Fetch status using specific Backup Job ID  
- Display timestamps, duration, and detailed phases

### ✔ Multi-Language Support
- Shell scripting for quick & simple tasks  
- Python for modular, complex automation  
- Utility functions for reusable logic

---

## 🏗 Architecture

See `docs/architecture.md` for diagrams.

**High-level view:**

User → CCAH Scripts → CDP CLI → CDP Control Plane → DL/DH/Backup APIs

---

## 📁 Repository Structure

