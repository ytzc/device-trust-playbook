# Soteria-native Device Identity & Provisioning vs OP-TEE fTPM — Survey

**最後更新：** 2026-06-12  
**研究方向：** John 2026-06-12 更新  
**狀態：** 內部研究草稿，能力待 Techmation / Soteria 廠商確認  
**HTML 版本：** [docs/soteria-native-device-identity-provisioning-survey.html](../docs/soteria-native-device-identity-provisioning-survey.html)  
**相關分析：** [notes/techmation-tx8-soteria-optee-ftpm-analysis.md](./techmation-tx8-soteria-optee-ftpm-analysis.md)

---

## 1. Executive Summary

**John 最新研究方向（2026-06-12）：**

TX8 的整合路線研究重點，從「OP-TEE fTPM 可行性」轉移到「Soteria 能否直接支援 DevID/provisioning/mTLS」。

核心問題：
> **在 TX8 上，可以不用 OP-TEE fTPM，直接用 Soteria hRoT 完成 device identity、設備初始化、DevID provisioning、mTLS 認證嗎？**

John 的考量：
- OP-TEE 記憶體佔用大（通常需要 2–8 MB Secure World 記憶體）
- OP-TEE + fTPM 整合成本高（BSP、TF-A、OP-TEE OS、fTPM TA 四層）
- 如果只需要 DevID / mTLS，不需要完整 TPM/fTPM 功能集
- 但架構必須保留未來 remote attestation 和 CRA evidence 的擴展空間

**初步結論（2026-06-12）：**

| 評估項目 | Soteria-native | OP-TEE fTPM |
|---------|---------------|-------------|
| DevID 所需加密基礎 | RSA/HMAC/AES/TRNG 已確認 | TPM 2.0 完整實作 |
| DevID 專用 API | ⚠️ 待確認 | ✅ TPM2_CreatePrimary + TPM2_Certify |
| 記憶體佔用 | 低（Soteria 在 HW IP，不需 SW overhead） | 高（OP-TEE OS + fTPM TA） |
| 整合工程量 | 中（custom adapter needed） | 高（BSP + 四層 SW stack） |
| TPM 相容性 | 無 TSS2 API | 完整 TSS2 / TPM2 Provider |
| 未來 RA 擴展 | 待確認 Soteria PCR/quote | 直接支援 TPM Quote |
| TX8 平台前提 | 僅需 Soteria AHB driver | 需 TrustZone 支援（未確認） |

> **重要：** 本文所有 Soteria 能力標記 "⚠️ TBC" 者，均需透過 Techmation / Soteria 廠商 SDK 和文件確認，不可提前承諾。

---

## 2. Research Goal

### 主要研究目標

1. **可行性評估**：Soteria hRoT 是否具備直接支援 IEEE 802.1AR DevID 的技術能力？
2. **整合成本比較**：Soteria-native path vs OP-TEE fTPM path 的工程量比較
3. **記憶體評估**：OP-TEE 記憶體佔用對 TX8 平台的影響
4. **延伸性設計**：如何設計 backend-agnostic 架構，保留未來 Remote Attestation 擴展空間

### 次要研究目標

5. 確認 Soteria 是否支援 ECDSA（相比 RSA 更適合 IoT 設備 DevID）
6. 確認 Soteria OTP（8KB）是否足夠儲存 DevID key pair 和 certificate
7. 確認 Soteria 的 key management API 能否實現 non-exportable private key（符合 IEEE 802.1AR 要求）
8. 評估 CSR 生成工作量（Soteria 提供 signing，但 CSR ASN.1 encoding 可能在 SW 層）

### 研究邊界

- **範圍內：** TX8 + Soteria 的 Device Identity + Provisioning + mTLS 路線
- **範圍外：** 其他平台（PLANET MTK、x86）的 DevID 路線（另有文件）
- **研究工具：** 本文分析，最終需 Soteria SDK / Techmation 技術文件確認

---

## 3. Terminology

| 術語 | 定義 |
|------|------|
| **DevID** | Device Identity — 設備身份憑證（通稱） |
| **IDevID** | Initial Device Identifier — 出廠時燒錄的不可更換設備身份（IEEE 802.1AR） |
| **LDevID** | Locally Significant Device Identifier — 現場部署後發放的可更換操作身份 |
| **IEEE 802.1AR** | DevID 標準：定義 IDevID/LDevID 的技術規範，包含 non-exportable private key 要求 |
| **mTLS** | Mutual TLS — 雙向 TLS 憑證認證，用於設備與後端服務的相互認證 |
| **TTPS DI** | FiduciaEdge 設備身份佈建服務 |
| **Soteria-native path** | 直接使用 Soteria AHB MSG API 實現 DevID，不依賴 OP-TEE fTPM |
| **OP-TEE fTPM path** | 在 TX8 ARM SoC TrustZone Secure World 中執行 OP-TEE fTPM TA |
| **Device Trust Abstraction Layer** | 提議的 backend-agnostic 介面層，統一支援 Soteria / TPM / fTPM 等不同 RoT 後端 |
| **Black Key** | Soteria 的 HW-protected key wrapping 機制（ENZMK+ENBK+MAC），raw HUK 不離開 Soteria |
| **HUK** | Hardware Unique Key — 設備唯一根密鑰，來自 Soteria TRNG + OTP |
| **CSR** | Certificate Signing Request — 向 CA 申請憑證的請求，包含公鑰和設備資訊 |
| **CRA** | EU Cyber Resilience Act 2024/2847，全面強制執行 2027-12-11 |

---

## 4. Soteria-native Device Identity Architecture

### 4.1 架構概念

Soteria-native DevID path 的核心概念：

```
製造端 (Factory)
  │
  ▼
[1] Soteria OTP 燒錄 Root Provisioning Key (RPK) / ROK 安裝 (INSTALL_ROK)
  │
  ▼  
[2] Soteria 生成 Device Key Pair (TBC: RSA or ECDSA key gen within Soteria)
    private key → 以 Black Key 形式保護，永不離開硬體邊界
    public key  → 導出供 CSR/Certificate 使用
  │
  ▼
[3] 設備上的 SW 層（OP-TEE 或 Linux）使用 Soteria RSA 簽名能力
    生成 CSR (ASN.1 encoding 在 SW 層，簽名在 Soteria 硬體)
  │
  ▼
[4] CSR 送往 TTPS DI / CA → 簽發 IDevID Certificate
  │
  ▼
[5] Certificate 儲存（OTP 8KB 有限，可能需外部 secure flash + Black Key 保護）
  │
  ▼
現場部署
  │
  ▼
[6] 設備使用 Soteria 私鑰簽名 → mTLS 握手認證
  │
  ▼
[7] 未來擴展：Soteria 提供 firmware measurement evidence（TBC）
              → CRA Annex I 對應的設備完整性 evidence
```

### 4.2 與 OP-TEE fTPM 的架構差異

| 架構面向 | Soteria-native | OP-TEE fTPM |
|---------|---------------|-------------|
| Key 保護層 | Soteria 硬體 IP（AHB 隔離） | OP-TEE TrustZone Secure World |
| Key API | Soteria AHB MSG0–MSG15 command | TPM2_CreatePrimary / TPM2_Create |
| 簽名 API | MSG0=0x3 (RSA) TBC: ECDSA | TPM2_Sign |
| 憑證儲存 | Soteria OTP (8KB) + 外部 flash（TBC） | OP-TEE Secure Storage (SFS) |
| 上層 API | Custom Soteria adapter → TTPS DI | TSS2 / OpenSSL TPM2 Provider |
| TrustZone 需求 | 不需要（Soteria 透過 AHB 存取） | 需要（OP-TEE 執行在 TZ Secure World） |

### 4.3 Soteria 作為 DevID 硬體基礎

已確認的加密基礎（來自架構文件）：

- **TRNG** (MSG0=0x4)：產生 device-unique random，可作為 key generation 基礎
- **RSA** (MSG0=0x3)：非對稱加密 / 簽名（512/1024/2048-bit，PKCS#1 v1.5）
- **Black Key** (MSG0=0x12/0x14)：key wrapping，保護私鑰不離開硬體邊界
- **OTP** (8KB)：不可更改儲存，適合 IDevID root material
- **KEY_HASH_CHK** (MSG0=0x15)：hash 驗證，可用於身份驗證

尚待確認的能力（TBC）：

- ECDSA / ECC P-256 支援（RSA 較大，IoT 設備更常用 ECC）
- Soteria 是否有 "generate key pair, export only public key" 的封裝 API
- OTP 空間分配：DevID key material 佔用多少 OTP？
- Certificate 儲存方案（8KB OTP 可能不夠存整張 X.509 cert）

---

## 5. Soteria API Capability Survey

### 5.1 DevID 所需能力 vs Soteria 已知能力

| # | DevID 所需能力 | Soteria 現有 API | 狀態 | 備註 |
|---|--------------|----------------|------|------|
| 1 | 硬體唯一根秘密（HUK） | TRNG (0x4) + OTP | ✅ 已確認 | TRNG 生成，OTP 儲存 |
| 2 | RSA 私鑰生成（非可導出） | TRNG + Black Key (0x12/0x14) | ⚠️ TBC | 需確認是否有封裝 key gen API |
| 3 | RSA 公鑰導出 | OTP access (MSG0=0x8)? | ⚠️ TBC | 需確認公鑰導出機制 |
| 4 | RSA 簽名（用於 mTLS / CSR） | RSA (0x3) PKCS#1 v1.5 | ✅ 已確認 | 可直接用於 TLS 簽名 |
| 5 | ECDSA 簽名（P-256/secp256r1） | 未見於文件 | ❌ TBC | IoT 標準；需確認是否支援 |
| 6 | ECC 私鑰生成 | 未見於文件 | ❌ TBC | 若無 ECC 需改用 RSA-2048 |
| 7 | HMAC-SHA256 / SHA384 | HMAC (0x2) | ✅ 已確認 | 可用於 integrity check |
| 8 | AES 對稱加密（cert 儲存保護） | AES (0x1) | ✅ 已確認 | 可配合 Black Key 保護儲存 |
| 9 | TRNG（key material 生成） | TRNG (0x4) | ✅ 已確認 | 硬體真亂數 |
| 10 | OTP 儲存（不可更改 key material） | 8KB OTP | ✅ 已確認 | 容量限制需評估 |
| 11 | Non-exportable private key | Black Key (0x12/0x14) | ⚠️ TBC | Black Key 機制保護；API 完整性待確認 |
| 12 | CSR 生成（ASN.1 encoding） | 無（SW 層工作） | 📋 SW 實作 | CSR 由 SW 組裝，Soteria 負責簽名 |
| 13 | X.509 Certificate 儲存 | OTP (8KB) + 外部 flash? | ⚠️ TBC | 8KB OTP 可能不夠，需確認方案 |
| 14 | Certificate Renewal / LDevID | OTP 不可更改 | ⚠️ TBC | LDevID 更新需外部 secure storage |
| 15 | mTLS private key 使用（online） | RSA (0x3) 簽名 | ⚠️ TBC | 需確認 mTLS handshake 工作流程 |
| 16 | Key rotation（LDevID 更換） | AES_BK (0x14)? | ⚠️ TBC | Black Key 可保護新 key，但機制待確認 |
| 17 | Device provisioning lifecycle 控制 | INSTALL_ROK (0x11) | ⚠️ TBC | ROK 安裝視為 provisioning 入口 |
| 18 | Debug lock / lifecycle state | Debug (MSG0=0x7) | ⚠️ TBC | Debug port 控制存在，lifecycle API 待確認 |
| 19 | Firmware measurement（PCR-like） | 未見於文件 | ❌ TBC | Remote Attestation 需求；高優先確認 |
| 20 | Attestation quote / signed report | 未見於文件 | ❌ TBC | CRA Phase 3 需求 |
| 21 | Monotonic counter（freshness） | 未見於文件 | ❌ TBC | 防 replay 需求 |
| 22 | Secure time / timestamp | 未見於文件 | ❌ TBC | 可由上層 SW 補充 |
| 23 | Secure Boot anchor（公鑰驗證） | KEY_HASH_CHK (0x15) + RSA_OTP (0x16) | ✅ 已確認 | 可用於 identity anchor |
| 24 | Anti-rollback counter | BOOT_IMG_ID (0x17) | ✅ 已確認 | 防 downgrade |
| 25 | Linux userspace 直接存取 Soteria | 未見於文件（目前 SW 需通過 OP-TEE/Secure World） | ⚠️ TBC | 決定 architecture 複雜度的關鍵 |
| 26 | Provisioning mode / factory mode | 未見於文件 | ⚠️ TBC | 製造端 IDevID 燒錄流程 |
| 27 | Identity attestation（Soteria 自我 identity 證明） | 未見於文件 | ❌ TBC | DevID certification 可能需要此功能 |

### 5.2 能力狀態統計

| 狀態 | 數量 | 能力 |
|------|------|------|
| ✅ 已確認 | 7 | HUK、RSA 簽名、HMAC、AES、TRNG、OTP、Secure Boot anchor、Anti-rollback |
| ⚠️ TBC | 13 | Key gen、公鑰導出、Non-exportable、Cert 儲存、mTLS flow、Provisioning lifecycle 等 |
| ❌ TBC (可能不支援) | 7 | ECDSA、ECC、Firmware measurement、Attestation quote、Monotonic counter、Linux 直接存取 |
| 📋 SW 實作 | 1 | CSR 生成（Soteria 提供 signing，SW 組裝 ASN.1） |

---

## 6. OP-TEE fTPM Path Analysis

### 6.1 OP-TEE fTPM 概述

OP-TEE fTPM 是在 ARM TrustZone Secure World 中執行的 TPM 2.0 firmware 實作。

**技術堆疊：**
```
Linux (Normal World)
    │
    │ /dev/tpmX (TPM character device)
    ▼
tpm2-abrmd (TPM resource manager daemon)
    │
    │ TEE Client API / OP-TEE driver
    ▼
OP-TEE OS (Secure World, ARM TrustZone)
    │
    ▼
fTPM Trusted Application (TA)
    │ based on Microsoft TPM 2.0 Reference Implementation
    ▼
OP-TEE Secure Storage (SFS, backed by HUK-encrypted flash)
```

**對外 API：** TSS2 / OpenSSL TPM2 Provider（與 hTPM 完全相同）

### 6.2 記憶體佔用分析

| 元件 | 典型記憶體需求 |
|------|-------------|
| TrustZone Secure World 總需求 | 4–16 MB（TF-A + OP-TEE OS + TA） |
| OP-TEE OS 本身 | 1–4 MB |
| fTPM TA | 512 KB–2 MB |
| OP-TEE Secure Storage | 額外 flash 配置 |
| TF-A (BL31 Secure Monitor) | 256–512 KB |

**TX8 記憶體限制：** 待確認（若 TX8 系統記憶體緊張，OP-TEE 佔用可能是問題）

### 6.3 OP-TEE fTPM 的 DevID 能力

| DevID 能力 | fTPM 支援 | API |
|-----------|----------|-----|
| RSA / ECC 私鑰生成 | ✅ | TPM2_CreatePrimary + TPM2_Create |
| Non-exportable private key | ✅ | TPM_PT_FIXED_PARENT |
| 公鑰導出 | ✅ | TPM2_ReadPublic |
| RSA / ECDSA 簽名 | ✅ | TPM2_Sign |
| X.509 Certificate 儲存 | ✅ | OP-TEE SFS（flash-backed） |
| Provisioning API | ✅ | TPM2_NV 或 PKCS#11 |
| Firmware measurement | ✅ | PCR 0–23 |
| Attestation quote | ✅ | TPM2_Quote |
| Monotonic counter | ✅ | TPM2_NV |
| Linux mTLS integration | ✅ | OpenSSL TPM2 Provider |

### 6.4 OP-TEE fTPM 的 TX8 前提條件（待確認）

1. **TX8 主 SoC 支援 ARM TrustZone：** ⚠️ 未確認
2. **BSP 包含 TF-A（Trusted Firmware-A）：** ⚠️ 未確認
3. **OP-TEE OS 可在 TX8 BSP 上啟用：** ⚠️ 未確認
4. **fTPM TA 可編譯並整合到 OP-TEE build：** ⚠️ 未確認
5. **Secure Boot 啟用（Phase 3 需求）：** ⚠️ 未確認
6. **TX8 系統記憶體足夠支援 OP-TEE：** ⚠️ 未確認

---

## 7. Soteria-native vs OP-TEE fTPM 直接比較

| 比較維度 | Soteria-native | OP-TEE fTPM |
|---------|---------------|-------------|
| **TX8 平台前提** | 僅需 Soteria AHB driver | TrustZone + TF-A + OP-TEE OS |
| **記憶體佔用** | 低（Soteria 是硬體 IP，無 SW overhead） | 高（4–16 MB Secure World） |
| **TX8 可行性** | 高（Soteria 已在 TX8 上） | ⚠️ 待確認 TrustZone 支援 |
| **DevID 基礎加密** | RSA/HMAC/AES/TRNG 已確認 | 完整 TPM 2.0 |
| **DevID 專用 API** | ⚠️ TBC（需 custom adapter） | ✅ TPM2 標準 API |
| **Non-exportable key** | ⚠️ TBC（Black Key 機制） | ✅ TPM hardware binding |
| **ECDSA 支援** | ❌ TBC（RSA 已確認） | ✅ |
| **mTLS 整合** | ⚠️ TBC（需 custom OpenSSL engine or adapter） | ✅ OpenSSL TPM2 Provider |
| **Certificate 儲存** | ⚠️ TBC（OTP 8KB 限制） | ✅ OP-TEE SFS（flash 加密） |
| **TSS2 API 相容** | ❌（非 TPM 標準） | ✅ |
| **Custom adapter 工程量** | 高（DevID 全套需自建） | 低（已有 TSS2/TPM2 Provider） |
| **未來 RA / attestation** | ❌ TBC（PCR/quote 待確認） | ✅ TPM2_Quote |
| **CRA Phase 3 支援** | ❌ TBC | ✅ |
| **可移植到其他平台** | 低（Soteria 專屬） | 高（TSS2 API 跨平台） |
| **整合複雜度** | 中（custom adapter，但 Soteria 已就緒） | 高（若 TX8 TrustZone 需先確認） |

### 決策建議

**短期（2026）：** 如果 TX8 TrustZone 未確認，Soteria-native 是唯一可行的主要路線。

**中長期：** 設計 backend-agnostic Device Trust Abstraction Layer，讓上層 TTPS DI 不需要知道底層是 Soteria 還是 fTPM。

---

## 8. Device Trust Abstraction Layer（未來相容設計）

### 8.1 設計動機

無論 TX8 最終採用 Soteria-native 還是 OP-TEE fTPM，TTPS DI 服務和上層應用都不應該直接依賴底層 RoT API。需要一個 **backend-agnostic 抽象層**，讓：

1. TTPS DI 可以對接 Soteria-native、TPM/fTPM、OP-TEE 或未來其他 hRoT
2. 不同平台（TX8、PLANET MTK、x86）使用相同上層 API
3. 未來新增 Remote Attestation 不需要重寫上層邏輯

### 8.2 抽象層介面設計（概念）

```
應用層 / TTPS DI
    │
    │  (標準化介面)
    ▼
Device Trust Abstraction Layer
    ┌──────────────────────────────────────────────────┐
    │  dt_generate_key(type, size) → key_handle        │
    │  dt_get_public_key(key_handle) → pub_key_bytes   │
    │  dt_sign(key_handle, data) → signature           │
    │  dt_generate_csr(key_handle, subject) → csr_der  │
    │  dt_store_cert(cert_der, slot) → ok              │
    │  dt_get_cert(slot) → cert_der                    │
    │  dt_get_attestation_evidence() → evidence        │  # Phase 3 擴展
    └──────────────────────────────────────────────────┘
         │                │                │
         ▼                ▼                ▼
  Soteria Backend   TPM/fTPM Backend   OP-TEE Backend
  (AHB MSG API)     (TSS2 / tpm2-tools) (TEE Client API)
```

### 8.3 各後端對應關係

| 抽象層介面 | Soteria 後端（TBC） | TPM/fTPM 後端 |
|-----------|-------------------|--------------|
| dt_generate_key | TRNG + Black Key（TBC） | TPM2_CreatePrimary + TPM2_Create |
| dt_get_public_key | OTP / RSA pub key export（TBC） | TPM2_ReadPublic |
| dt_sign | MSG0=0x3 RSA sign | TPM2_Sign |
| dt_generate_csr | SW ASN.1 + Soteria sign | SW ASN.1 + TPM2_Sign |
| dt_store_cert | OTP / external flash + AES_BK | OP-TEE SFS / TPM2_NV |
| dt_get_cert | OTP / flash read | OP-TEE SFS / TPM2_NV read |
| dt_get_attestation_evidence | TBC（Soteria 未確認） | TPM2_Quote |

---

## 9. Proposed Direction

### 9.1 短期（2026-Q3）

**主要研究路線：Soteria-native DevID path**

1. 取得 Soteria SDK 完整文件，確認 Section 5 所有 TBC 項目
2. 特別確認：ECDSA 支援、key gen API、non-exportable key、cert 儲存方案
3. 若 Soteria 支援 DevID 所需全部能力：實作 Soteria-native DevID adapter
4. 若 Soteria 缺少關鍵能力（如 ECDSA）：評估 RSA-2048 替代方案

**備用路線：OP-TEE fTPM path**

1. 同步確認 TX8 SoC 是否支援 ARM TrustZone
2. 若支援：評估 OP-TEE BSP 整合工程量
3. 作為 Soteria-native 的備用選項

### 9.2 中期（2026-Q4 至 2027）

1. 設計並實作 Device Trust Abstraction Layer
2. Soteria backend 和 TPM/fTPM backend 都實作
3. TTPS DI 遷移到抽象層 API

### 9.3 長期（2027+ / CRA Phase 3）

1. 擴展抽象層，支援 Remote Attestation evidence generation
2. Soteria：若確認支援 measurement/quote，接入 attestation flow
3. OP-TEE fTPM：TPM2_Quote 直接接入
4. 準備 CRA Annex I 技術 evidence 文件

---

## 10. Questions for John / Soteria / Techmation

### A. Soteria API 能力確認

1. **[CRITICAL]** Soteria 是否支援在硬體內生成 RSA key pair，且 private key 永不離開 Soteria（non-exportable）？用哪個 MSG 命令？
2. **[CRITICAL]** Soteria 是否支援 ECDSA（P-256 / secp256r1）？若無，RSA-2048 是否為可接受的 DevID 替代方案？
3. Soteria 的 8KB OTP 如何規劃使用空間？DevID key material 可以使用多少？
4. X.509 Certificate（通常 1–4 KB）如何在 TX8 上儲存？OTP 空間夠嗎？或需要外部 flash + Black Key 保護？
5. Soteria 是否有 "generate key pair, keep private, export public" 的封裝 API，或需自行組合 MSG 命令？
6. Soteria 的 RSA 命令（MSG0=0x3）是否支援 RSA-PSS padding（現代 TLS 更推薦），或只支援 PKCS#1 v1.5？

### B. Provisioning 流程確認

7. **[CRITICAL]** Soteria 的 INSTALL_ROK (MSG0=0x11) 是 manufacturing-time only，還是 field-deployable？
8. TX8 的製造端 provisioning flow 是什麼？Techmation 是否有 factory provisioning toolkit？
9. Soteria 是否有 "provisioning mode" / "production mode" 切換機制（對應 IDevID 製造端燒錄 vs 現場部署）？
10. LDevID（現場更換 identity）的 key rotation 如何在 Soteria-native path 實現？

### C. mTLS / 整合確認

11. Soteria 的 AHB driver 目前在 OP-TEE Secure World 還是 Linux Normal World 執行？Linux userspace 可以直接使用 Soteria API 嗎？
12. 使用 Soteria RSA key 進行 TLS handshake 的完整工作流程是什麼（應用層如何調用 Soteria 做 TLS client auth）？

### D. Remote Attestation / CRA 相關

13. **[CRITICAL]** Soteria 是否支援 firmware measurement（記錄開機時 image hash）？是否有 PCR-like 暫存器？
14. **[CRITICAL]** Soteria 是否可以產生 signed attestation report / quote（類似 TPM2_Quote）？
15. Soteria 是否有 monotonic counter（用於 attestation freshness / nonce-based anti-replay）？

### E. TX8 SoC TrustZone 確認

16. TX8 使用的主 ARM SoC 型號是什麼？
17. 該 SoC 是否支援 ARM TrustZone？BSP 是否已啟用 TF-A + OP-TEE？
18. 若支援 TrustZone，估計啟用 OP-TEE 的 BSP 工程量（從現有 BSP 到 OP-TEE 就緒）？

### F. 架構設計確認

19. Soteria 在 TX8 上的 bus isolation 配置：TZASC 還是 PMP？Soteria AHB registers 是否只有 Secure World 可存取？
20. 若 TX8 SoC 支援 TrustZone，Soteria 在 Secure World 是否可見？OP-TEE Secure World 可以直接控制 Soteria AHB？

---

## 11. CRA-ready 解讀

### 11.1 Soteria-native Path 的 CRA Support 能力

| CRA Annex I 要求 | Soteria-native 支援 | 狀態 | 備註 |
|----------------|-------------------|------|------|
| (2)(d) Device identity | Hardware-bound key (RSA) | ⚠️ TBC | 需確認 non-exportable key API |
| (2)(e) Key protection | Black Key mechanism | ⚠️ TBC | API 完整性待確認 |
| (2)(f) Firmware integrity | Secure Boot (KEY_HASH_CHK/RSA_OTP) | ✅ 已確認 | Soteria Secure Boot anchor |
| (2)(f) Measured Boot | PCR-like measurement | ❌ TBC | 高優先確認項目 |
| (2)(k) Attestation | Signed quote | ❌ TBC | CRA Phase 3 需求 |
| (2)(l) Software update integrity | Anti-rollback (BOOT_IMG_ID) | ✅ 已確認 | 防 downgrade |

### 11.2 OP-TEE fTPM Path 的 CRA Support 能力

| CRA Annex I 要求 | OP-TEE fTPM 支援 | 狀態 | 備註 |
|----------------|----------------|------|------|
| (2)(d) Device identity | TPM2_CreatePrimary + cert | ✅ 標準支援 | 需 TX8 TrustZone 確認 |
| (2)(e) Key protection | TPM hardware binding | ✅ | TPM non-exportable key |
| (2)(f) Firmware integrity | Secure Boot + PCR 0–7 | ✅ | 需 Secure Boot 啟用 |
| (2)(f) Measured Boot | PCR 0–23 | ✅ | 完整支援 |
| (2)(k) Attestation | TPM2_Quote | ✅ | 完整支援 |
| (2)(l) Software update integrity | PCR measurement + anti-rollback | ✅ | 完整支援 |

### 11.3 CRA 定位聲明規則

- ✅ 可以說：「TX8 Soteria hRoT 提供 hardware-bound key protection，是 CRA-ready 設備安全的技術基礎」
- ✅ 可以說：「CRA compliance 取決於完整系統設計，包含 key management、update pipeline、vulnerability handling」
- ❌ 不可說：「Soteria 已確認完整支援所有 CRA DevID 要求」
- ❌ 不可說：「Soteria-native path 可以替代 TPM 用於 CRA attestation」
- ❌ 不可說：「不需要 OP-TEE fTPM 也一定安全」

---

## 12. Action Items

| 優先 | 任務 | 負責 | 截止 |
|------|------|------|------|
| P0 | 取得 Soteria SDK 完整技術文件（含 key management API） | John / Techmation | ASAP |
| P0 | 確認 Soteria 是否支援 ECDSA（或確認 RSA-only） | John / Techmation | ASAP |
| P0 | 確認 TX8 主 SoC 型號 + TrustZone 支援 | Techmation | ASAP |
| P0 | 確認 non-exportable key gen API（Section 5 Q1） | John / Soteria doc | ASAP |
| P1 | 確認 OTP 8KB 空間分配方案（DevID key + cert 儲存） | John / Techmation | Q3 |
| P1 | 確認 Soteria 是否支援 firmware measurement / attestation | Soteria doc / Techmation | Q3 |
| P1 | 確認 provisioning mode 和 lifecycle 控制 API | Soteria doc | Q3 |
| P2 | 設計 Device Trust Abstraction Layer（基於 P0/P1 結果） | FiduciaEdge TTPS | Q3-Q4 |
| P2 | 實作 Soteria-native DevID adapter（基於確認的 API） | FiduciaEdge TTPS | Q4 |
| P3 | 評估 OP-TEE fTPM path（若 TX8 TrustZone 確認支援） | FiduciaEdge TTPS | Q4 |
| P3 | 擴展 TTPS DI 接受 Soteria-native path | FiduciaEdge TTPS | Q4 |

---

*維護：FiduciaEdge TTPS 團隊 · 2026-06-12*  
*所有 Soteria 能力標記 "⚠️ TBC" 或 "❌ TBC" 者均需廠商文件確認，不可提前承諾*
