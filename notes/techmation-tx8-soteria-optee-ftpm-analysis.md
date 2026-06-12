# Techmation TX8 + Soteria hRoT + OP-TEE fTPM Analysis
# Techmation TX8、Soteria hRoT 與 OP-TEE fTPM 可行性分析

**最後更新：** 2026-06-12  
**狀態：** 內部研究筆記 — 待確認事項多，請勿對外承諾  
**HTML 版本：** [docs/techmation-tx8-soteria-optee-ftpm-analysis.html](../docs/techmation-tx8-soteria-optee-ftpm-analysis.html)  
**關聯筆記：**  
- [notes/platform-solution-decision-map.md](./platform-solution-decision-map.md)  
- [notes/rot-methods-comparison.md](./rot-methods-comparison.md)  
- [notes/2026-06-12-rot-discussion-meeting-prep.md](./2026-06-12-rot-discussion-meeting-prep.md)

---

## 1. Executive Summary / 執行摘要

Techmation TX8 目前已知的 RoT 路線是 **Soteria hRoT**，透過 vendor-specific API 提供 secure key storage、device identity 等能力。

現在需要進一步確認：**TX8 是否也能採用 OP-TEE fTPM 方法，或兩者的 Hybrid 組合？**

### 關鍵架構澄清

- **OP-TEE 跑在主 ARM SoC 的 TrustZone Secure World**，不是跑在 Soteria hRoT 上
- fTPM TA 是跑在 OP-TEE 裡的 Trusted Application，需要主 SoC 支援 ARM TrustZone
- Soteria hRoT 是獨立的 hardware security module，透過 vendor API 被主系統呼叫
- **正確問題是：TX8 主 SoC 是否支援 ARM TrustZone / OP-TEE？**
- 若支援，才可評估 OP-TEE fTPM
- 若同時有 Soteria hRoT，則應評估三種路線：
  1. **Path A：** Soteria hRoT API only
  2. **Path B：** OP-TEE fTPM only（若 SoC 支援 TrustZone）
  3. **Path C：** Hybrid — OP-TEE fTPM + Soteria hRoT-backed secure storage

**⚠️ 目前 TX8 主 SoC 型號、TrustZone 支援狀況、BSP 狀態均未確認，以下為 conceptual analysis。**

---

## 2. Architecture Clarification / 架構釐清

### 元件角色表

| 元件 | 角色 | 備註 |
|------|------|------|
| TX8 main SoC | 執行 Linux / application；也可能支援 TrustZone / OP-TEE | 型號未確認 |
| OP-TEE | 跑在主 ARM SoC TrustZone Secure World 的 TEE OS | 需 SoC + BSP 支援 |
| fTPM TA | 跑在 OP-TEE 裡的 TPM-like Trusted Application | 通常基於 MS TPM 2.0 Ref Impl |
| Soteria hRoT | 硬體信任根 / secure key storage / crypto / identity / vendor RoT | TX8 已有 |
| Soteria API | 主系統或 secure software 呼叫 Soteria hRoT 的整合介面 | Vendor-specific |

### Conceptual Architecture（概念架構）

```
TX8 Main SoC（ARM Cortex-A？— 型號待確認）
├─ Normal World: Linux / Application
│  ├─ TTPS DI / device identity client
│  ├─ TSS2 stack（若有 fTPM）
│  └─ Soteria API client
│
├─ Secure World: OP-TEE（若 SoC + BSP 支援）
│  └─ fTPM TA（若有 enable + 整合）
│     ├─ TPM 2.0 command interface
│     └─ Persistent state（secure storage）
│
└─ Soteria hRoT（硬體模組，可能透過 SPI / I2C / dedicated bus）
   └─ Vendor API / secure key storage / crypto engine / device identity
```

**⚠️ 重要：OP-TEE 跑在主 SoC Secure World，不是跑在 Soteria hRoT 上。Soteria hRoT 是獨立元件。以上為 conceptual architecture，實際取決於 TX8 SoC 型號與 Soteria 的硬體整合方式。**

---

## 3. Three Possible Integration Paths / 三種可能路線

### Path A：Soteria hRoT API Only

**說明：**  
不使用 TPM API，直接透過 Soteria vendor API 做 secure key storage、device identity、crypto operation、firmware integrity 或 attestation evidence。

| 項目 | 說明 |
|------|------|
| 是否需 TrustZone / OP-TEE | 不需要 |
| 是否使用 Soteria hRoT | 是 |
| API 標準 | Soteria vendor-specific |
| TTPS DI 整合 | 需 custom adapter：Soteria API → TTPS DI flow |

**優點：**
- TX8 已有 Soteria，不需額外平台變更
- 不依賴 BSP TrustZone / OP-TEE 支援
- API 路徑清晰（若 SDK 已取得）

**缺點：**
- 需開發 custom adapter layer（工程量）
- Soteria API 未必符合 TCG TPM 2.0 標準
- 若客戶要求 TPM 2.0 compatibility，此路線無法滿足
- Phase 3 Remote Attestation 能力需另外確認

**CRA-ready 能力：**
- ✅ Secure key storage（待確認 API 支援）
- ✅ Device identity（待確認 non-exportable key）
- ⚠️ Firmware integrity / Measured Boot（待確認 Soteria 是否支援）
- ⚠️ Attestation evidence（待確認 Soteria quote mechanism）

**需確認的 API：**
- Soteria: secure key generation / storage
- Soteria: key wrapping / sealing
- Soteria: device unique identity
- Soteria: firmware measurement / PCR-like slots
- Soteria: attestation quote / signed evidence
- Soteria: SDK 文件與授權條款

---

### Path B：OP-TEE fTPM Only

**說明：**  
TX8 主 SoC 若支援 TrustZone / OP-TEE，可在 OP-TEE 中跑 fTPM TA，提供標準 TPM 2.0 command interface。

| 項目 | 說明 |
|------|------|
| 是否需 TrustZone / OP-TEE | **是（必要前提）** |
| 是否使用 Soteria hRoT | 不一定（不直接使用） |
| API 標準 | TPM 2.0 / TSS2 / OpenSSL TPM2 Provider |
| TTPS DI 整合 | 可直接使用現有 TSS2 path（移植，不是重寫） |

**優點：**
- 標準 TPM 2.0 API，與 x86 hTPM path 相同
- TTPS DI 可直接移植（無需 custom adapter）
- Phase 1/2/3 完整支援（如平台就緒）
- MS TPM 2.0 Reference Implementation 基礎，社群成熟

**缺點：**
- 前提是 TX8 SoC 支援 TrustZone + BSP 有 OP-TEE（**目前未確認**）
- 如果 TX8 已有 Soteria hRoT，此路線可能不使用 Soteria（資源重複疑慮）
- BSP 啟用工程量（+2~4w lead time 若需整合 TF-A + OP-TEE OS + fTPM TA）
- 需確認 TX8 上 TrustZone / OP-TEE 是否已啟用或可啟用

**CRA-ready 能力：**
- ✅ Secure key storage（TZ Secure World 保護）
- ✅ Device identity（TPM IDevID/LDevID）
- ✅ Firmware integrity（PCR / Measured Boot）
- ✅ Attestation（TPM quote）

**需確認的平台條件：**
1. TX8 main SoC 型號（是否為 ARM Cortex-A？）
2. TX8 SoC 是否支援 ARM TrustZone？
3. TX8 BSP 是否已含 TF-A（BL1/BL2/BL31）？
4. TX8 BSP 是否已有 OP-TEE OS（BL32）？
5. fTPM TA 是否已在 OP-TEE build 中啟用？
6. 如果未啟用，是否可以 enable？工程量？

---

### Path C：Hybrid — OP-TEE fTPM + Soteria hRoT-backed Secure Storage

**說明：**  
OP-TEE fTPM 提供 TPM-like API 給 Normal World；Soteria hRoT 作為底層硬體保護，用於 OP-TEE secure storage 的 key protection，或 fTPM persistent state 的 hardware-backed key wrapping。

| 項目 | 說明 |
|------|------|
| 是否需 TrustZone / OP-TEE | **是（必要前提）** |
| 是否使用 Soteria hRoT | **是（作為底層加固）** |
| API 標準 | TPM 2.0 / TSS2（對外）；Soteria API（內部整合） |
| 整合複雜度 | **最高** |

**概念：**
```
Normal World
└─ TSS2 → fTPM TA（Secure World）
             └─ Persistent keys / state
                └─ OP-TEE Secure Storage
                   └─ Soteria hRoT-backed key protection
                      └─ Hardware key wrapping / sealing
```

**優點：**
- TPM 2.0 compatibility（TSS2 / TPM2 Provider）
- Soteria hRoT 作為底層硬體加固，key protection 更強
- 既有 Soteria 硬體不浪費
- CRA-ready 能力最完整（如技術上可行）

**缺點：**
- 整合複雜度最高
- 需要確認：OP-TEE fTPM 是否能使用 Soteria 作為 secure storage backend
- 需要確認：Soteria API 是否暴露 key wrapping / sealing interface 給 OP-TEE
- 需要確認：Soteria 是否在 Secure World 可見（不只是 Normal World）
- 工程量最大；可能是研究性質，不是近期 deliverable

**CRA-ready 能力：**
- ✅ Secure key storage（Soteria-backed）
- ✅ Device identity（TPM-based）
- ✅ Firmware integrity（PCR-based）
- ✅ Attestation（TPM quote）
- ✅ Hardware-backed key protection（最強）

**需確認的技術條件：**
- Soteria hRoT 在 ARM SoC 架構中的存取層（Secure World 可見？Normal World only？）
- OP-TEE secure storage driver 是否支援 custom hardware backend（RPMB / vendor SE）
- Soteria API 是否有 key wrapping / derivation interface
- fTPM TA 的 NV storage 加密 key 管理機制

**風險：**
- 此路線為研究 candidate，目前尚無已知 production reference
- 整合驗證工程量可能超過 Phase 1/2 需求
- 建議先確認 Path A 或 Path B 可行後，再評估 Hybrid

---

## 4. Decision Table / 決策表

| 決策因素 | Path A：Soteria API Only | Path B：OP-TEE fTPM Only | Path C：Hybrid（fTPM + Soteria） |
|---------|------------------------|------------------------|-------------------------------|
| 需要 TrustZone / OP-TEE | 不需要 | **必需** | **必需** |
| 需要 TPM API 相容性 | 否 | 是 | 是 |
| 使用 Soteria hRoT | 是（直接） | 否（間接或不用） | 是（底層加固） |
| Secure key storage | Soteria-backed | OP-TEE secure storage | Soteria-backed（hardware-protected） |
| Device identity | Vendor API based | TPM credential (IDevID/LDevID) | TPM-like identity backed by Soteria |
| Firmware integrity | Vendor-specific（待確認） | TPM PCR / Measured Boot | TPM PCR + Soteria measurement（待確認） |
| Remote attestation | Vendor-specific evidence（待確認） | TPM quote / PCR evidence | Potentially strongest（但複雜） |
| 整合複雜度 | Medium | Medium–High（BSP 前提） | **High** |
| CRA-ready 強度 | Medium（若 API 足夠） | Strong（若平台就緒） | Strongest（若技術可行） |
| TTPS DI 移植工程量 | 高（custom adapter） | 低（直接 TSS2 path） | 高（hybrid adapter） |
| 目前狀態 | **待確認 Soteria API** | **待確認 TX8 TrustZone / OP-TEE** | **研究 candidate** |

---

## 5. Key Questions for John / Techmation

### TX8 SoC / TrustZone / OP-TEE

1. TX8 main SoC 是哪一顆？是否為 ARM Cortex-A 系列（A9/A53/A55/A72…）？
2. TX8 SoC 是否支援 ARM TrustZone（TZASC / Secure World / Normal World 分離）？
3. TX8 BSP 是否已有 TF-A（Trusted Firmware-A，BL1/BL2/BL31）？
4. TX8 BSP 是否已有 OP-TEE OS（BL32）？
5. 如果沒有 OP-TEE，是否有計畫啟用？工程量估算？

### Soteria hRoT

6. Soteria hRoT 是 external chip（透過 SPI/I2C 連接）、SoC 整合 IP，還是 dedicated security MCU？
7. Soteria API 目前支援哪些功能（已知 / 待確認）：
   - ☐ secure key generation
   - ☐ secure key storage（persistent）
   - ☐ key wrapping / sealing（hardware-binding）
   - ☐ crypto operation（AES, ECC, RSA）
   - ☐ device unique identity / certificate
   - ☐ firmware measurement / PCR-like slots
   - ☐ attestation evidence / signed quote
8. Soteria hRoT 是否可被 OP-TEE Secure World 存取（還是只有 Normal World 可以用）？
9. OP-TEE fTPM 是否能把 persistent state 或 key material 委託 Soteria hRoT 做 key wrapping？

### 整合路線偏好

10. Techmation 是否需要 TPM 2.0 API compatibility（TCG spec / TSS2）？
11. CRA support 需要標準 TPM evidence，還是 Soteria vendor-specific evidence 可接受？
12. Remote attestation 是近期目標，還是 Phase 3 roadmap？
13. 是否有量產成本、BOM cost、third-party certification 考量（TPM 晶片 vs Soteria-only）？

---

## 6. Recommended Current Position / 建議目前說法

### 繁體中文

> Techmation TX8 的 **primary known path** 是 Soteria hRoT。
>
> OP-TEE fTPM 可作為 **candidate path** 或 **hybrid path**，但前提是 TX8 主 SoC 支援 ARM TrustZone / OP-TEE，且需確認 Soteria API 是否能支援 secure storage、key protection、measurement 或 attestation integration。
>
> 在 TX8 SoC 型號、TrustZone 支援狀況、Soteria API capability 確認之前，不建議對外承諾具體的 TX8 RoT 技術路線。

### English

> The **primary known path** for Techmation TX8 is the **Soteria hRoT** via vendor-specific API.
>
> OP-TEE fTPM remains a **candidate path** or **hybrid path**, subject to confirmation that TX8's main SoC supports ARM TrustZone / OP-TEE, and that the Soteria hRoT API provides the necessary secure storage, key protection, measurement, and attestation integration interfaces.
>
> Until the TX8 SoC model, TrustZone support, and Soteria API capabilities are confirmed, we should not commit to a specific TX8 RoT integration path in customer-facing communications.

---

## 7. CRA Support Interpretation

Soteria hRoT、OP-TEE fTPM、Hybrid path 都是 **CRA-ready technical foundation**，但均不等於完整 CRA compliance。

### RoT 對 CRA 的支援重點

| CRA 技術要求 | Soteria hRoT | OP-TEE fTPM | Hybrid Path |
|------------|-------------|------------|-------------|
| Device identity（Annex I 2d） | 待確認 | ✅ IDevID/LDevID | ✅ |
| Secure key storage（Annex I 2e） | 待確認 | ✅ TZ-protected | ✅（hardware-backed） |
| Firmware integrity（Annex I 2f） | 待確認 | ✅ PCR/Measured Boot | ✅ |
| Attestation foundation（Annex I 2f/k/l） | 待確認 | ✅ TPM quote | ✅（strongest） |

### CRA 還需要（不在 RoT 範圍）

- Vulnerability handling / PSIRT 程序
- Security updates pipeline（依 CRA Annex I 第 2 條）
- Product risk assessment（OEM 責任）
- Conformity assessment 文件與 CE marking（OEM 責任）

---

## Architecture Design: OP-TEE Supported by Soteria hRoT
## 架構設計：由 Soteria hRoT 支援的 OP-TEE

> **更新：2026-06-12** — 根據 Soteria AHB 架構規格，本節提供更精確的架構設計說明。

### AD.1 Overview / 概述

**Soteria Security Subsystem** 是一個透過 AHB memory-mapped interface 存取的硬體 IP 模組，具備：
- 內部 **RISC-V ibex** 處理器（執行 firmware routine）
- **8KB 安全 OTP**（public key hash / Root of Key / device secrets，不可修改）
- 多種**硬體密碼加速器**（AES / HMAC / RSA / TRNG）

**OP-TEE** 是一個開源 Secure OS，執行於主處理器 **ARM TrustZone Secure World** 或 **RISC-V PMP** 保護的 secure execution environment。

**關鍵架構關係：**
- **主處理器執行 Normal World（Linux）和 Secure World（OP-TEE）**
- **Soteria hRoT 作為 Hardware Root-of-Trust、hardware-backed secure storage provider、cryptographic co-processor 與 secure boot verification anchor**
- **OP-TEE 不在 Soteria 上執行；Soteria 透過 AHB memory-mapped interface 由 Secure World driver 存取**
- **Bus isolation（TZASC / PMP）確保 Normal World 無法直接存取 Soteria register region**

### AD.2 System Architecture & Bus Isolation / 系統架構與匯流排隔離

Soteria 透過 AHB slave port 存取 memory-mapped registers（`0x00` 到 `0x60`）。

```
TX8 Host Processor（型號待確認）
├─ Normal World: Linux / Applications
│  └─ ❌ 無法直接存取 Soteria register region（bus isolation）
│
├─ Secure World: OP-TEE
│  ├─ Soteria Secure Driver（AHB R/W via MSG0–MSG15）
│  ├─ OP-TEE Crypto API（offload to Soteria AES/HMAC/RSA/TRNG）
│  ├─ Secure Storage / SFS（HUK 由 Soteria Black Key 保護）
│  └─ Optional fTPM TA（candidate path）
│
└─ Bus Protection（TZASC / PMP）
   └─ Soteria register region (0x00–0x60): Secure World-only

Soteria hRoT（AHB-connected）
├─ AHB Slave Port: MSG0–MSG15 (0x00–0x3C), Control (0x40–0x60)
│   ├─ PROC_START (0x40)  PROC_CANCEL (0x44)  PROC_BUSY (0x48)
│   ├─ INT_EN (0x4C)      INT_STATUS (0x50)
├─ AHB Master Port: Secure payload DMA（必須指向 Secure RAM）
├─ Internal RISC-V ibex processor（firmware execution）
├─ 8KB OTP: public key hash / ROK / device secrets（immutable）
└─ Crypto Accelerators: AES / HMAC / RSA / TRNG
```

**匯流排保護要求：**
- TZASC 或 PMP 設定：Soteria register region → Secure World-only
- Soteria AHB Master DMA target → Secure RAM only（`MSG3` / `MSG5`）
- Critical operations（OTP access `MSG0=0x8`，Debug `MSG0=0x7`）需 Magic Numbers（`0x6C33B567`、`0x473FA4AE`）

### AD.3 Integration Pillar 1：Secure Boot & Chain of Trust

**目標：** 在 OP-TEE 啟動前，由 Soteria 驗證其映像完整性，建立可信啟動鏈。

| 步驟 | 說明 |
|------|------|
| 1. ROM Bootloader | 主處理器上電，執行不可修改的 ROM bootloader |
| 2. 提交 OP-TEE hash | Bootloader 將 OP-TEE image hash 透過 Soteria AHB 提交 |
| 3. Soteria 驗證 | `MSG0 = 0x15`（KEY_HASH_CHK）或 `MSG0 = 0x16`（RSA_OTP），對照 OTP pubkey hash 驗證 |
| 4. OP-TEE 啟動 | 驗證通過 → OP-TEE 在 Secure World 啟動 |
| 5. Anti-rollback | OP-TEE 呼叫 `MSG0 = 0x17`（BOOT_IMG_ID）查詢 active boot image |

### AD.4 Integration Pillar 2：Hardware-Backed Secure Storage（HUK / Black Key）

**目標：** OP-TEE Secure Storage（SFS）的 HUK 由 Soteria hardware-backed Black Key 保護。**Raw HUK 永遠不離開 Soteria 內部**。

| 步驟 | Soteria 命令 | MSG0 | 說明 |
|------|------------|------|------|
| 1. ROK 安裝 | INSTALL_ROK | `0x11` | Root of Key 安裝，以 ROK password 認證 |
| 2. Black Key 生成 | CREATE_BK | `0x12` | TRNG 生成 key + ROK 加密 → 回傳 Black Key（ENZMK+ENBK+MAC） |
| 3. 透明 AES | AES_BK | `0x14` | OP-TEE 提供 Black Key + payload，Soteria 在內部解密並完成 AES |

**安全優勢：** OP-TEE 只持有加密後的 Black Key，無法還原 raw HUK；raw key 不進入 OP-TEE RAM。

### AD.5 Integration Pillar 3：OP-TEE Crypto API Offloading

| OP-TEE API | Soteria 命令 | MSG0 | 規格 |
|-----------|------------|------|------|
| TEE_CipherInit / Update | AES | `0x1` | 128/192/256-bit，ECB/CBC/CTR |
| TEE_DigestUpdate / MACUpdate | HMAC | `0x2` | SHA-256/384/512，SHA3-512，MD5 |
| TEE_AsymmetricEncrypt / Decrypt | RSA | `0x3` | RSA-512/1024/2048，PKCS#1 v1.5 |
| TEE_GenerateRandom | TRNG | `0x4` | True random number generation |

### AD.6 OP-TEE Soteria Driver Workflow

1. **Interrupt Setup**：啟用 `INT_EN @ 0x4C`，註冊 Soteria IRQ handler
2. **Busy Wait**：確認 `PROC_BUSY @ 0x48 = 0`（idle）
3. **Buffer Preparation**：input / output buffer 在 Secure RAM；flush data cache
4. **Message Configuration**：寫入 `MSG0–MSG15`（`0x00–0x3C`）
5. **Trigger**：寫入 `1` 到 `PROC_START @ 0x40`
6. **Completion**：等待 Soteria IRQ，讀 `INT_STATUS @ 0x50`（`[0]`成功，`[1]`失敗，`[2]`取消）

**Security Considerations：**
- Process Cancellation：`PROC_CANCEL @ 0x44`（需 `PROC_BUSY = 1`）
- Magic Numbers：OTP access / Debug control 需 `0x6C33B567`、`0x473FA4AE`（防止 driver bug 造成意外操作）
- Single operation model：Soteria 每次處理一個操作，driver 需管理 concurrency

### AD.7 CRA-Ready Value

| CRA-ready 領域 | Soteria + OP-TEE 貢獻 | 待確認 |
|--------------|---------------------|--------|
| Secure by design | Bus isolation + OP-TEE Secure World + Soteria HW isolation | TX8 bus isolation TBC |
| 防未授權存取 | TZASC/PMP；Secure World-only Soteria；Magic Number 保護 | TZASC/PMP 設定 TBC |
| Secure key storage | Black Key mechanism；raw HUK 不離開 Soteria | Black Key path 驗證 TBC |
| Firmware 完整性 | KEY_HASH_CHK / RSA_OTP；OTP-bound pubkey；anti-rollback | OTP pubkey 配置 TBC |
| 密碼能力 | AES/HMAC/RSA/TRNG hardware accelerators | TBC |
| Device identity | Soteria OTP-bound secrets（identity API 待確認） | Soteria identity API TBC |
| Remote attestation | Soteria quote 待確認；或搭配 OP-TEE fTPM（candidate） | 待確認 |

> **⚠️ 此架構支援 CRA readiness 與合規證據準備，但不等於單獨保證完整 CRA compliance。**

### AD.8 Open Questions / 待確認

1. TX8 主處理器是否支援 ARM TrustZone 或 RISC-V PMP？
2. TX8 是否已有 OP-TEE port / BSP 支援？
3. Soteria register region 是否可由 TZASC / PMP 設成 Secure World-only？
4. Soteria AHB Master payload buffer 是否能限制在 Secure RAM？
5. Black Key mechanism 是否可直接支援 OP-TEE Secure Storage HUK / SFS？
6. Soteria 是否能作為 OP-TEE fTPM persistent state / key wrapping backend？
7. Soteria 是否有 device unique identity API？
8. Soteria 是否支援 attestation quote / signed measurement report？
9. 是否需要 TPM 2.0 API compatibility？
10. Magic Numbers / OTP access / debug control 的安全 policy 如何設計？

---

## 8. Action Items / 後續動作

- [ ] 向 Techmation 確認 TX8 SoC 型號（ARM？TrustZone？）
- [ ] 向 Techmation 取得 Soteria SDK / API spec
- [ ] 建立 Soteria API capability matrix（逐條確認 13 個問題）
- [ ] 確認 TX8 BSP TF-A + OP-TEE 現有狀態
- [ ] 評估 Path B（OP-TEE fTPM）feasibility（若 TrustZone 確認）
- [ ] 評估 Path C（Hybrid）technical feasibility（研究性質）
- [ ] 補 customer-facing wording（依確認結果選擇 Path A/B/C）
- [ ] 更新 CRA Annex mapping（加入 TX8 specific evidence path）

---

## 來源狀態

| 資料 | 狀態 |
|------|------|
| TX8 SoC 型號 / TrustZone 支援 | ⚠️ **未確認 — 需問 Techmation** |
| Soteria API spec / SDK | ⚠️ **未取得 — 需向 Techmation 申請** |
| Soteria attestation 能力 | ⚠️ **未確認** |
| OP-TEE fTPM TX8 BSP 狀態 | ⚠️ **未確認** |
| MS TPM 2.0 Reference Impl 相關文件 | 公開可用（github.com/microsoft/ms-tpm-20-ref） |
| CRA Annex I 原文 | 可參閱 references/cra/OJ_L_202402847_EN_TXT.pdf |

---

*維護：FiduciaEdge TTPS 團隊 · 2026-06-12 · 內部研究文件，非法律合規聲明*
