# Device Trust & CRA Readiness Current Summary

# 設備信任與 CRA Readiness 目前整理

**最後更新：** 2026-06-11
**狀態：** 內部知識筆記，非法律合規聲明
**來源：** `../cra-compliance-readiness/` repo 所有 Markdown 文件

---

## 1. Executive Summary / 執行摘要

### 核心方向

我們建立的不是單純的「CRA compliance 服務」，而是 **Device Trust & Platform Security** 能力。CRA 是其中一個重要的合規驅動與客戶需求場景，但整體能力遠超出 CRA 本身的範疇。

**能力核心：**
- Root of Trust（硬體信任根）：TPM 2.0 / fTPM / hTPM / Soteria hRoT / External SE
- Device Identity：IDevID / LDevID，hardware-bound，non-exportable private key
- Secure Provisioning / Onboarding：FDO、TTPS DI service（已在 Ubuntu+TPM 驗證）
- Firmware Integrity：Secure Boot + Measured Boot + PCR-like evidence
- Remote Attestation：Measured Boot evidence + signed report + NMS policy engine
- CRA Evidence Readiness：Annex I technical control mapping + audit trail + SBOM

**定位說法：**
> FiduciaEdge 提供 CRA 所需安全控制的技術實作基礎，協助 OEM 客戶建立 CRA-ready 產品安全架構。Conformity assessment 與 CE marking 的法律責任仍在產品製造商（OEM）。

**重要區分：**
- 我們提供：「支援 CRA-required controls」/ 「CRA compliance support」
- 不說：「符合 CRA」/ 「guarantee CRA compliance」/ 「CRA certified」

---

## 2. Current Customer / Project Context

### 2.1 PLANET Technology — Gateway 產品線

**場景：** PLANET 為台灣網路設備製造商，產品涵蓋 Managed Switch、L2/L3 Gateway、Industrial Edge Gateway。高階 Gateway 可能落入 **CRA Important Class I**（Annex III），需通過 harmonized standard 或第三方審查。

**已知資訊：**
- 部分高階 Gateway 使用 ARM 處理器（MTK 平台，含 TrustZone 潛力）
- 部分 Switch / Bridge 產品使用 Legacy MIPS SoC（無 hardware RoT）
- FiduciaEdge 提出三階段 RA 提案

**三階段提案：**

| Phase | 英文名稱 | 核心交付 | 阻擋條件 |
|-------|---------|---------|---------|
| Phase 1 | Device Identity & Secure Provisioning | 將 TTPS DI 從 Ubuntu+TPM **移植**為 MTK OpenWRT + TrustZone fTPM；hardware-bound device identity | MTK BSP OP-TEE + fTPM TA 就緒；硬體樣品 |
| Phase 2 | Root of Trust & Key Protection | VPN/mTLS private key 移入 TrustZone；PKCS#11 / TPM2 Provider 整合 | Phase 1 完成；VPN 技術選定 |
| Phase 3 | Remote Attestation & CRA Evidence | Measured Boot → PCR；RA client；NMS Verifier；Pass/Fail/Unknown policy | Phase 1/2 完成；Secure Boot；SBOM pipeline；NMS API 定義 |

**待確認：**
- MTK BSP 是否含 TrustZone + OP-TEE 啟用 + fTPM TA 正常運作
- 各產品型號 SoC 清單（ARM / MIPS / RISC-V 分布）
- 是否有 External SE 接頭（Path B 可行性）
- Secure Boot 是否已啟用
- VPN/mTLS 技術選擇（StrongSwan / OpenVPN / 其他）
- SBOM pipeline 是否已建立
- 各產品線出貨量 / EOL 狀態

**MIPS 產品線注意：** MIPS 架構本身不是阻礙——問題在於特定 MIPS SoC 缺乏 hardware RoT。若無 hardware RoT，只能提供 gap analysis + compensating controls，不可承諾 hardware-bound RA。

---

### 2.2 Techmation TX8

**場景：** Techmation TX8 是內嵌 **Soteria hRoT** 的設備平台。Soteria 是 Techmation 的 hardware Root of Trust，透過 vendor-specific API 存取，不使用標準 TPM API。

**已知資訊：**
- 有 hardware Root of Trust（Soteria hRoT）
- 透過 Soteria/vendor API 整合，**不是 TPM2 API**
- Phase 1（Device Identity）與 Phase 2（Key Protection）可行
- Phase 3（Remote Attestation）需另確認 Soteria 是否支援 attestation quote mechanism

**適用 Solution Path：** Path TX8（vendor-specific hRoT）

**待確認：**
- Soteria hRoT API 的 attestation quote 能力
- Measured Boot / PCR-like register 是否存在
- Phase 3 可行性

---

### 2.3 i.MX93 / NXP EdgeLock 2GO / TTPS / FDO

**場景：** 以 NXP i.MX93 為目標 SoC 的產品平台，結合 FiduciaEdge TTPS DI service 與 FDO（FIDO Device Onboard）協定。此場景有早期分析文件（analysis/01）。

**i.MX93 硬體能力（來自 NXP AN14601 Rev 1.1, 2025-06-25）：**
- ELE（EdgeLock Secure Enclave）：晶片內獨立安全域，Root of Trust
- AHAB（Advanced High Assurance Boot）：Secure Boot
- TrustZone：ARM TrustZone，可建立 OP-TEE Secure World + fTPM TA
- BBSM、RDC、OTFAD：各種安全機制
- SESIP Level 3 / PSA Certified Level 3：第三方技術認證（不等同 CRA compliance）

**EdgeLock 2GO 的角色與衝突風險（來自 meeting/04）：**
- EL2GO 是 NXP 提供的 Cloud Provisioning 服務，控制 Root CA / Sub-CA、Secure Object 注入、Ownership Transfer
- **核心衝突：** 若 NXP 透過 EL2GO 控制 Root CA，FiduciaEdge 的 Chain of Trust 設計就建立在 NXP 的信任錨點上，FiduciaEdge 失去架構主導權
- FiduciaEdge 立場：Chain of Trust 定義、Attestation 設計、Threat Modeling 應由 FiduciaEdge 主導

**FDO 的角色：**
- 標準化 zero-touch provisioning 協定（FIDO Alliance）
- 透過 ownership voucher 機制，讓設備在出廠後自動、安全完成 onboarding
- 對應 CRA 安全預設配置要求

**⚠️ 注意：** AN14601 明確聲明不保證 CRA 法律確定性，僅為技術路徑指引。i.MX93 SESIP 認證是技術佐證，不是 CRA conformity declaration。

**CRA Annex I × i.MX93 × FDO × TTPS 技術 Mapping：** 詳見 `../cra-compliance-readiness/analysis/01_CRA_iMX93_TTPS_FDO_TPM2_Analysis.md`

---

### 2.4 Mitwell e-Box（來自會議備忘）

**場景：** FiduciaEdge 正在為 Mitwell 進行 CRA compliance workshop。涉及 NXP EL2GO 整合（Root CA sovereignty 是關鍵考量）。

**待確認：** Mitwell 具體產品 SoC 型號、EL2GO 整合邊界、Root CA 歸屬決策。

---

### 2.5 Legacy MIPS Switch / Bridge

**場景：** PLANET 等客戶部分舊有產品使用 MIPS SoC（優化於封包處理），無 TrustZone、無 hardware TPM 接頭、無 hardware key storage。

**已知限制（John Zao PDF 分析）：**
- 無 native TPM / TrustZone
- 無物理 TPM 接頭（SPI/I2C）
- Software PCR 可被取得 root 的攻擊者修改
- 無法實作 non-exportable hardware-bound key

**可提供：** Gap analysis + Compensating controls（SBOM、signed firmware update、mTLS with software key、CVD policy）
**不可承諾：** Hardware-bound identity、non-exportable key、Remote Attestation evidence 可信度

---

## 3. Solution Naming and Positioning

### 主名稱（長期品牌）

**Device Trust & Platform Security Playbook**

這是 FiduciaEdge 的技術能力知識庫，涵蓋 Device Identity → RoT → Provisioning → Onboarding → Firmware Integrity → Remote Attestation 的完整技術棧。

### 客戶-facing Solution 名稱

**CRA-Ready Device Trust & Platform Security Solution**

使用說明：
- 用於向 OEM 客戶定位我們能提供的技術服務
- 強調「CRA-ready」而非「CRA compliance guaranteed」
- 適合搭配 conformity assessment 業務（法律責任仍在 OEM）

### 正確說法與不可說說法

| 情境 | ✓ 可以說 | ✗ 不可以說 |
|------|---------|----------|
| 整體定位 | CRA-ready, CRA compliance support, CRA readiness foundation | fully compliant with CRA, guarantees CRA compliance |
| 技術能力 | supports CRA-related evidence preparation | makes the product fully compliant |
| 認證 | technical security controls for CRA Annex I | CRA certified |
| 責任邊界 | Conformity assessment 責任在製造商 | FiduciaEdge 負責 CE marking |
| Phase 1 說明 | 移植既有 TTPS DI（Ubuntu+TPM → OpenWRT+fTPM） | 從零開發 DI |

---

## 4. Platform Solution Decision Table

| Platform / Scenario | Recommended RoT / Solution | TPM Used? | Integration API | CRA-ready Capability | Risk / Assumption | Status |
|--------------------|-----------------------------|-----------|-----------------|---------------------|-------------------|--------|
| **x86** | hTPM (discrete or integrated) | ✅ TPM 2.0 | TPM2-Software-Stack (TSS2) / OpenSSL TPM2 Provider | Phase 1/2/3 完整適用；TTPS DI 已在此平台驗證 | hTPM vendor / supply chain | 已驗證 |
| **ARM / TrustZone + OP-TEE (BSP 啟用)** | OP-TEE fTPM Trusted Application | 🔄 fTPM（虛擬 TPM） | TPM2 Provider / tpm2-pkcs11；OpenWRT TSS | Phase 1/2/3 完整適用；PLANET 提案主要交付範圍 | MTK BSP OP-TEE + fTPM TA 需確認；Secure Boot 需確認 | 規劃中 |
| **ARM / TrustZone（BSP 未啟用）** | 先啟用 OP-TEE + fTPM TA，再走 ARM path | 🔄 fTPM（待建立） | 同上 | 同上，需額外工程量啟用 TEE | BSP 移植工作量未知 | 需評估 |
| **Techmation TX8** | Soteria hRoT（vendor-specific API） | ❌ 非 TPM API | Soteria vendor SDK / API | Phase 1/2 可行；Phase 3 需確認 attestation quote | Soteria Phase 3 能力未確認 | 評估中 |
| **任意平台 + External SE + PKCS#11** | External Secure Element | ❌ 非 TPM（SE） | PKCS#11 standard interface | Phase 1/2 可行；Phase 3 需另確認 Measured Boot + PCR + quote | SE 是否有 boot measurement 能力 | 需逐 SE 評估 |
| **任意平台 + External SE + vendor SDK only** | External SE（vendor SDK） | ❌ | Vendor-specific SDK | Phase 1/2 可行（工程量較大）；Phase 3 TBD | 需 custom adapter；標準化程度低 | 需逐案設計 |
| **高出貨量產品（無 SE）** | 建議硬體改版加 External SE | 依 SE 型號 | 依 SE 型號 | 改版後走 External SE path | BOM 增量需量產規模攤薄 | 需客戶決策 |
| **Legacy MIPS（無任何 hardware RoT）** | Gap Analysis + Compensating Controls only | ❌ 無 | 無硬體 anchor | 僅限 SBOM + signed update + mTLS（軟體金鑰） | 不可承諾 hardware-bound RA | Gap analysis |
| **RISC-V 新平台** | Per-SoC capability assessment | 依 SoC | 依 SoC | 不可預設；需逐 SoC 評估安全能力 | RISC-V 無統一 TrustZone 等效標準 | 需評估 |
| **VM / KVM / QEMU（開發測試環境）** | vTPM / swtpm | 🔄 vTPM | TPM2 Provider（與實體 TPM 相同） | 僅適用開發/測試；不可用於生產環境 CRA compliance | 虛擬化環境無法提供 physical isolation | 測試用途 |
| **i.MX93 + NXP EL2GO** | ELE + AHAB + OP-TEE fTPM；EL2GO 僅作 provisioning 服務（非 RoT 控制） | 🔄 fTPM | TTPS DI + EL2GO（邊界待定義） | Phase 1/2/3 潛力強；但 Root CA sovereignty 需決策 | EL2GO 控制 Root CA 會影響 FiduciaEdge 架構主導權 | **需確認** |

> **⚠️ PKCS#11 ≠ 完整 Remote Attestation：** PKCS#11 解決 key operations（簽署/加密），不提供 Secure Boot、Measured Boot、PCR-like registers、attestation quote。Phase 3 需要這些額外能力，需逐平台確認。

---

## 5. Capability Model

### 5.1 Device Identity

**目的：** 每台設備具備唯一、不可偽造的身份（IDevID / LDevID），hardware-bound，non-exportable private key。

**對 CRA readiness：** 直接對應 Annex I (2)(d) Authentication & Identity Management。是所有後續安全功能的信任基礎。

**平台相依性：** 高。需要 hardware RoT（TPM / fTPM / SE）。無 hardware RoT 的平台只能使用軟體金鑰（可信度弱）。

**目前證據：** TTPS DI 在 Ubuntu+TPM 平台已驗證；x86+hTPM path 為 known-good reference。

---

### 5.2 Secure Device Registration

**目的：** 設備 identity 建立後，向 backend（TTPS service / CA / Registry）完成登記，建立 device lifecycle record。

**對 CRA readiness：** 支援 (2)(d) Access Management；提供設備 fleet 的身份稽核基礎。

**平台相依性：** 中。Registration protocol 可平台無關（HTTPS + cert），但 device cert 必須來自 hardware-bound key。

**目前證據：** TTPS DI 含 device registration；FDO ownership voucher 機制可作為 zero-touch registration。

---

### 5.3 Secure Initialization / Provisioning

**目的：** 製造時或部署時，安全地將 device key + certificate 注入設備，並建立安全預設配置。Zero-touch 或 minimal-touch。

**對 CRA readiness：** 對應 (2)(b) Secure-by-default；設備出廠即具備 hardware-bound identity，無「不安全預設狀態」。

**平台相依性：** 高（key 必須在 hardware RoT 中產生）。

**目前證據：** TTPS DI service（Ubuntu+TPM 已驗證）；FDO 協定。Phase 1 = 移植 TTPS DI 至 MTK OpenWRT + fTPM。

---

### 5.4 Root of Trust Integration

**目的：** 將平台的 hardware RoT（TPM 2.0 / fTPM / hRoT / External SE）正確整合到 OS / Application 層，提供 hardware-isolated key operations。

**對 CRA readiness：** 對應 (2)(d)(e)(k)；private key 不離開 hardware boundary。

**平台相依性：** 極高。各平台 RoT API 不同：
- x86 hTPM → TSS2 / OpenSSL TPM2 Provider
- ARM fTPM → TPM2 Provider（同 hTPM API）
- Techmation TX8 → Soteria vendor API
- External SE → PKCS#11 standard interface or vendor SDK

**目前證據：** 三階段提案 Phase 1（ARM fTPM 整合）；meeting/04 分析 EL2GO 的衝突風險。

---

### 5.5 Secure Key Storage / Key Protection

**目的：** Long-term private key 永遠不離開 hardware-protected storage，即使 OS 被攻陷也無法提取。

**對 CRA readiness：** 對應 (2)(e) Confidentiality、(2)(k) Incident Mitigation。

**平台相依性：** 高。無 hardware RoT 的平台只有 software key storage，可被 root-level 攻擊者提取。

**目前證據：** fTPM 的 non-exportable key attribute；TPM2_Create 的 fixedParent + fixedTPM key properties。

---

### 5.6 Firmware Integrity

**目的：** 確保設備運行的 firmware 是原廠授權版本，未被篡改。包含 build-time signing 和 deploy-time verification。

**對 CRA readiness：** 對應 (2)(f) Integrity；(2)(b) Secure-by-default。

**平台相依性：** 高。需要 Secure Boot（boot chain signature verification）。

**目前證據：** PLANET 三階段提案要求 PLANET 提供已啟用的 Secure Boot；SBOM 簽署由 PLANET release key 完成。

---

### 5.7 Secure Boot Readiness

**目的：** Boot chain（BL2 → BL31 → BL32/OP-TEE → BL33 → Linux kernel → OpenWRT rootfs）每個階段都必須由前一層驗證簽章才能執行。

**對 CRA readiness：** 對應 (2)(b)(f)；bootloader 竄改可被偵測並阻止。

**平台相依性：** 極高。PLANET 目標平台的 Secure Boot 狀態為 **待確認**（PLANET-side dependency）。無 Secure Boot，Phase 3 完整性保證顯著減弱。

**目前證據：** i.MX93 有 AHAB；MTK 平台 Secure Boot 狀態待 PLANET 確認。

---

### 5.8 Measured Boot Readiness

**目的：** 在 Secure Boot 基礎上，將每個 boot 階段的 cryptographic hash **extend** 到 fTPM PCR-like registers。提供可驗證的 boot 狀態 evidence。

**對 CRA readiness：** 是 Phase 3 Remote Attestation 的核心前提；沒有 Measured Boot 就沒有 verifiable boot integrity evidence。

**平台相依性：** 極高。需要 hardware write-once registers（PCR-like）；PKCS#11-only 平台無此能力。

**目前證據：** TrustZone fTPM 的 PCR-like slots；Phase 3 任務清單。

---

### 5.9 Remote Attestation Roadmap

**目的：** 讓 NMS 能遠端驗證設備的 boot + runtime integrity，並依驗證結果做 policy decision（Pass / Fail / Unknown）。

**對 CRA readiness：** 對應 (2)(f)(k)(l)；提供 tamper-evident runtime evidence，支援 attestation-gated access control。

**平台相依性：** 極高。需要完整能力棧：hardware RoT + Secure Boot + Measured Boot + PCR + attestation quote mechanism。

**重要提醒：** Remote Attestation 是 roadmap，不應對所有平台立即承諾。需逐平台確認能力，再決定可交付的 Phase。

**目前證據：** PLANET 三階段提案 Phase 3；analysis/07 mapping。

---

### 5.10 CRA Evidence Readiness

**目的：** 為 OEM conformity assessment 準備技術佐證材料，包含 CRA Annex I mapping 文件、RA audit trail、SBOM、security architecture 說明。

**對 CRA readiness：** 支援 OEM 執行 conformity assessment 的技術面準備；不等同合規本身。

**平台相依性：** 低。文件層面的工作可在任何平台進行（但技術佐證的強度取決於平台能力）。

**目前證據：** analysis/07, 08, 09；plan/01；`cra_ready_device_trust_platform_security_report.html`。

---

## 6. CRA Requirement Mapping

> ⚠️ **注意：** 以下為 CRA-related requirement mapping，基於 EU CRA 2024/2847 Annex I 條文整理。需在正式 conformity assessment 時對照官方 Annex I 原文驗證。不代表 FiduciaEdge 能獨立保證客戶產品完整符合 CRA。

| CRA 要求 | 相關 Annex I 條文 | 我方技術控制 | CRA-ready 程度 | Gap / 需 OEM 配合 |
|---------|----------------|------------|--------------|-----------------|
| Secure by design | (1), (a) | 三階段安全架構；hardware-rooted trust foundation | 支援架構設計 | OEM 需執行 threat model + risk assessment |
| Secure by default | (b) | 出廠即有 hardware-bound device identity；DI 自動化，無不安全預設狀態 | 強（Phase 1） | OEM 需停用 JTAG、關閉未使用介面、factory reset SOP |
| Security updates | (c), Part II (7)(8) | firmware signed update；attestation 驗證更新後狀態 | 部分（Phase 3） | OEM 需建立 OTA pipeline + 簽名金鑰管理 |
| AuthN / Access Control | (d) | IDevID/LDevID；mTLS；RA-gated management access | 強（Phase 1-3） | OEM 應用層 AuthZ policy |
| Data Confidentiality | (e) | hardware-protected VPN/mTLS key；non-exportable key；mTLS channel | 強（Phase 1-2） | OEM 確保所有管理介面強制 TLS |
| Data Integrity | (f) | Measured Boot + fTPM PCR；RA quote；firmware signature | 強（Phase 3） | OEM 需建立 Secure Boot chain |
| Data Minimisation | (g) | IDevID cert 欄位設計；不揭露不必要資訊 | 設計考量 | OEM 設計 cert profile |
| Availability / DoS | (h) | cert renewal + fallback 策略 | 設計考量 | OEM 應用層 DoS 防護 |
| Attack Surface | (j) | cert-based auth 取代預設密碼；DI 消除臨時設定路徑 | 部分（Phase 1-2） | OEM 停用 JTAG/SWD；關閉未使用 port |
| Incident Mitigation | (k) | hardware-protected key；private key 不可提取 | 強（Phase 1-2） | — |
| Logging / Monitoring | (l) | RA attestation audit log；cert event log；mTLS auth failure log | 強（Phase 3） | OEM 非 attestation 相關 event log |
| Secure Decommission | (m) | 安全刪除 LDevID、私鑰、trust anchor | 設計考量 | OEM decommission SOP |
| SBOM | Part II (1) | Known-Good Firmware SBOM Baseline DB（PLANET release key 簽署） | Phase 3 前提 | OEM 必須建立 SBOM 生成 + 簽署 pipeline |
| Vulnerability Handling | Part II (2)-(6) | SBOM 支援 CVE correlation；mismatch records | 部分支援 | OEM 必須建立 PSIRT + CVD policy + 公開 security contact |
| Secure Update Mechanism | Part II (7)(8) | attestation 驗證更新後 firmware 狀態 | 支援驗證層 | OEM 負責更新分發；PLANET release key 簽署 firmware |

---

## 7. PLANET Analysis

### 7.1 產品組合與硬體架構（已知）

| 產品類型 | 硬體架構 | RoT 能力 | RA 可行性 |
|--------|--------|---------|---------|
| 高階 Gateway（ARM MTK） | ARM TrustZone（待確認 OP-TEE + fTPM TA） | 潛力強，需 BSP 確認 | 三階段完整適用（Path A1） |
| 中階 Gateway / Bridge | 待確認 | 待確認 | 待 SoC 資訊後評估 |
| Legacy MIPS Switch / Bridge | MIPS（無 TrustZone，無 TPM 接頭） | 無 hardware RoT | 僅 compensating controls（Path E） |

### 7.2 CRA 對 PLANET 的核心要求

- **安全預設 (b)：** 不得使用共用預設密碼；出廠即佈建每台設備唯一身份
- **AuthN/AuthZ (d)：** 管理通道必須以 hardware-backed device credential 進行認證
- **安全通訊 (e)：** VPN/mTLS private key 不得從設備 storage 提取
- **Boot/軟體完整性 (b)(f)：** Firmware 必須在執行時可驗證真實性
- **安全更新 (c)：** 更新必須有簽章；設備激活前驗證
- **SBOM：** 每個 firmware 版本軟體元件清單；支援 CVE tracking
- **漏洞揭露：** 公開安全聯繫管道；定義 CVD policy

### 7.3 PLANET-side Dependencies（FiduciaEdge 不能單獨完成）

| 項目 | 用途 | 緊急程度 |
|-----|-----|--------|
| MTK BSP OP-TEE + fTPM TA 就緒 + 硬體樣品 | Phase 1 阻擋條件 | **Critical** |
| Secure Boot 啟用 | Phase 3 前提 | **High** |
| SBOM 生成 + 簽署 pipeline | Phase 3 attestation baseline | **Critical** |
| VPN/mTLS 技術選定 | Phase 2 設計 | **High** |
| NMS API 邊界定義 | Phase 3 NMS 整合 | **High** |
| 各產品 SoC 型號清單 | Platform path decision | **Critical** |

### 7.4 MIPS 產品線的正確說法

問題不在「MIPS」本身，而在這些特定 MIPS SoC **缺乏任何 hardware root-of-trust**。

- 若有 External SE + PKCS#11 → Phase 1/2 仍可能可行（需確認 SE 型號）
- 若無任何 hardware RoT → 只能提供 gap analysis + compensating controls
- MIPS → RISC-V / ARM 遷移計畫：若存在，是導入完整 RA 方案的機會

---

## 8. Techmation TX8 Analysis

### 8.1 技術架構

| 項目 | 詳情 |
|-----|-----|
| 平台 | Techmation TX8 |
| RoT 方案 | Soteria hRoT |
| API 介面 | Vendor-specific（非標準 TPM API，非 PKCS#11） |
| 可支援 Phase | Phase 1（Device Identity）、Phase 2（Key Protection）可行 |
| Phase 3 | 需另確認 Soteria 是否支援 Measured Boot + PCR-like registers + attestation quote |

### 8.2 整合方式

由於 Soteria 使用 vendor-specific API，FiduciaEdge 需要開發 **custom adapter layer**，將 TTPS DI flow 和 VPN/mTLS hardening 適配到 Soteria API。這比 TPM2 Provider path 工程量更大，但技術上可行。

### 8.3 對 CRA-ready 的意義

- **有 hardware RoT = 可建立 hardware-bound identity**（CRA (2)(d)(e)(k) 強覆蓋）
- Phase 3 能力取決於 Soteria 的 boot measurement + attestation quote 能力

### 8.4 待確認事項

- Soteria hRoT API spec（attestation quote 能力）
- Measured Boot / PCR-like register 是否存在
- Secure Boot 是否支援
- Phase 3 可行性評估

---

## 9. Remote Attestation Roadmap

Remote Attestation **是 roadmap，不是立即可用的功能**。應根據平台能力逐步建立，不應對所有平台過度承諾。

### 9.1 三階段導入路線

**Phase 1：Assessment + Device Identity Foundation**
- 確認目標平台 hardware capability（SoC audit）
- 建立 hardware-bound device identity（TTPS DI 移植或新整合）
- 確認 Root of Trust API（TPM2 / fTPM / SE / hRoT）
- 成果：每台設備有 hardware-bound cert；private key non-exportable

**Phase 2：RoT Integration + Firmware Integrity**
- VPN/mTLS hardening（PKCS#11 / TPM2 Provider）
- Secure Boot 確認或建立
- SBOM generation + signing pipeline
- 成果：management channel hardened；firmware integrity foundation

**Phase 3：Measured Boot / Remote Attestation / CRA Evidence Automation**
- Measured Boot 整合（boot stages → PCR extend）
- RA Client daemon
- NMS RA Verifier + Known-Good Baseline DB
- Policy Engine（Pass / Fail / Unknown）
- CRA evidence documentation
- 成果：NMS 可依 trust verdict 控制 management access；提供 CRA Annex I 技術佐證

### 9.2 各平台 Phase 3 能力需求

Phase 3 需要這 5 個條件（缺一不可）：
1. ✅ Secure Boot（boot chain 信任起點）
2. ✅ Measured Boot（boot stage hash extend 至 hardware-write-once registers）
3. ✅ PCR-like measurement slots（hardware write-once）
4. ✅ Signed attestation quote mechanism（由 device key 簽署）
5. ✅ NMS verifier integration

**PKCS#11 只解決條件 4 的一部分（key operation），不提供條件 1-3。** PKCS#11-only 平台無法完整支援 Phase 3。

---

## 10. What We Should Not Overclaim

| 不應說 | 更安全的替代說法 |
|-------|--------------|
| 我們保證完整 CRA compliance | 我們提供 CRA-ready 技術基礎；conformity assessment 為 OEM 責任 |
| 所有平台都可以用 TPM | TPM 是一種選項；關鍵需求是 hardware-protected key mechanism，各平台方案不同 |
| Legacy MIPS 不改硬體也可達到完整 secure boot / attestation | 無 hardware RoT 的 MIPS 平台只能提供 compensating controls，不可承諾 hardware-bound RA |
| PUF / hRoT 實體上不可破解 | PUF / hRoT 提供強硬體保護，但安全性有其假設與邊界條件，不應聲稱「完全無法攻破」 |
| Remote Attestation 可立即支援所有平台 | Remote Attestation 是 roadmap；Phase 3 需要完整的 Secure Boot + Measured Boot + PCR + quote 能力棧，需逐平台評估 |
| PKCS#11 = 完整 Remote Attestation | PKCS#11 解決 key operations；Phase 3 RA 還需要 Secure Boot、Measured Boot、PCR-like registers、attestation quote，PKCS#11 無法提供這些 |
| i.MX93 SESIP 認證 = CRA 合規 | i.MX93 SESIP/PSA 認證是第三方技術評估，可作為 CRA conformity assessment 的技術佐證，但不等同 CRA compliance 本身 |
| FiduciaEdge 負責 CE marking | CE marking 與 conformity assessment 的法律責任在產品製造商（OEM），FiduciaEdge 提供技術服務 |

---

## 11. Open Questions / 待確認事項

### PLANET 需提供

- [ ] 各產品型號 SoC 型號清單（ARM / MIPS / RISC-V / x86 分布）
- [ ] MTK BSP OP-TEE + fTPM TA 命令集覆蓋（TPM2 NV Index, ECDSA, PCR extend）
- [ ] 各產品 External SE 是否存在（及型號/介面）
- [ ] 各產品 Secure Boot 是否已啟用
- [ ] Measured Boot 是否支援（PCR-like registers 是否存在）
- [ ] VPN/mTLS 技術選擇（StrongSwan / OpenVPN / 其他）
- [ ] SBOM 生成 + 簽署 pipeline 是否已建立
- [ ] 各產品線出貨量 / EOL 狀態
- [ ] Device certificate 簽發 CA 選擇（TTPS CA / TWCA / PLANET OEM CA）
- [ ] NMS 整合 API 邊界定義
- [ ] MIPS-based 產品是否有遷移至 RISC-V / ARM 的計畫
- [ ] 工廠佈建整合點

### Techmation 需提供

- [ ] Soteria hRoT API spec（attestation quote capability）
- [ ] Measured Boot / PCR-like register 是否支援
- [ ] Secure Boot 狀態

### FiduciaEdge 內部需確認

- [ ] CRA 官方 Annex I 條文與 evidence requirements 的精確 mapping（請對照 EUR-Lex 原文）
- [ ] TTPS DI 與 FDO / EL2GO 的精確服務邊界
- [ ] EL2GO Root CA sovereignty 政策（對 Mitwell 場景）
- [ ] i.MX93 × TTPS DI × FDO × EL2GO 完整架構圖（需更新）
- [ ] 各功能項目的 Phase 1 / Phase 2 / Future roadmap 劃分（需與 PM 確認）
- [ ] TTPS 自身 PSIRT 流程是否已建立
- [ ] SBOM 管理範圍（TTPS 服務端 SBOM 由誰維護）
- [ ] 目標 OEM 產品分類（Non-important / Class I / Class II / Critical）確認

---

## 12. Source Files Reviewed

| Source File | Key Information Extracted |
|-------------|--------------------------|
| `analysis/01_CRA_iMX93_TTPS_FDO_TPM2_Analysis.md` | CRA Annex I 完整條列（a-m）；i.MX93 × FDO × TTPS × TPM mapping 主表；NXP AN14601 限制聲明；產品分類（Non-important/Class I/II/Critical） |
| `analysis/06_CRA_2024_Survey_Update.md` | CRA 整體法規概述；製造商主要義務；產品分類 × 合規路徑；PLANET Gateway 可能落入 Important Class I |
| `analysis/07_CRA_Requirement_to_TTPS_RA_Solution_Mapping.md` | CRA Annex I × 三階段 solution components 詳細 mapping；solution components 完整定義；Phase coverage summary |
| `analysis/08_PLANET_RA_CRA_Gap_Analysis.md` | PLANET 三階段 gap 分析；PLANET-side dependencies；FiduciaEdge deliverables；風險清單 R1-R10（含 MIPS 風險 R10） |
| `analysis/09_CRA_RA_Requirement_Solution_Matrix_Update.md` | 4-path platform applicability 矩陣；No-TPM Requirement Mapping；Eddie 決策樹整合 |
| `analysis/10_John_MIPS_CRA_PDF_Summary_and_Response.md` | John Zao MIPS 問題分析；Eddie 的 platform decision tree 補充（MIPS 不是絕對阻礙）；PKCS#11 限制說明；3 Scenarios 比對；Q1-Q14 待確認問題 |
| `plan/01_PLANET_Remote_Attestation_and_CRA_Solution_Plan.md` | 三階段完整任務清單；Phase 1 是移植（非新建）說明；§12 Platform Decision Tree（5 條路徑）；§13 No-TPM Solution Paths（4 條路徑）；PLANET-side dependencies |
| `meeting/02_One_Page_Meeting_Brief.md` | 單頁快速參考：技術組合 × CRA 覆蓋表；主要 gap；產品分類對合規路徑的影響 |
| `meeting/03_Meeting_Talk_Track.md` | 會議口頭腳本；定位宣告（「支援 CRA-required controls」vs「符合 CRA」）；i.MX93 / FDO / TPM 2.0 技術說明 |
| `meeting/04_NXP_EdgeLock2GO_Meeting_Prep.md` | EL2GO 架構解構；FiduciaEdge vs EL2GO 責任邊界；Root CA sovereignty 衝突風險；Chain of Trust 主導權問題 |
| `meeting/05_Self_Intro_Talk_Script.md` | FiduciaEdge 自我介紹腳本；T-REE 技術背景 |
| `meeting/06_PLANET_CRA_RA_One_Page_Brief.md` | PLANET 聯合會議一頁摘要；三階段 × CRA mapping；Platform Capability Decision（4 路徑表）；No-TPM Platform Handling；MIPS 回應說法 |
| `diagrams/PLANET_RA_Functional_Block_Diagram.md` | ARM TrustZone / Normal World / Secure World 架構功能方塊圖；platform applicability 說明 |
| `diagrams/PLANET_RA_Attestation_Flow.md` | 16 步驟 RA 完整流程（Mermaid sequenceDiagram）；Pass/Fail/Unknown 分支；CRA mapping 對照 |
| `input`（raw notes） | CRA 時程表；三模組英中名稱；CRA Annex I Part I (a-m) + Part II (1-8) 中英全文；IDevID mapping；目前硬體信任解決方案平台表 |
| `cra_ready_device_trust_platform_security_report.html` | 完整 HTML 視覺化報告；9 大節；3 Mermaid 圖；Platform Decision Map 含 flowchart；CRA Annex 全條文 bilingual 表格 |

**⚠️ 未完整解析：**
- `reference/AN14601, iMX93 CRA Guide.pdf`：NXP 官方 Application Note Rev 1.1（2025-06-25），文字內容未直接讀取，但關鍵限制聲明已透過 analysis/01 取得
- `reference/john/*.pdf`（5 份）：John Zao MIPS CRA 分析 PDF，文字未直接讀取，但內容已透過 analysis/10 整理
- `Project Proposal_ Mitwell workshop (LC3 JKZ1).docx`：Mitwell e-Box proposal DOCX，未讀取。需人工確認 Mitwell 具體需求與 SoC 資訊
- `reference/Map EU CRA to NXP iMX93 IoT (gSrchAI 26-03-15).pdf`：AI 生成 checklist（非官方，低可信度），未讀取

---

## 13. Gary's PLANET NMS CRA Enforcement Matrix

**來源：** `references/cra/PLANET_NMS_CRA_Enforcement_Matrix (GG1).xlsx`（Gary 分析）
**說明：** Gary 針對 PLANET NMS 現有功能，對照 CRA Annex I 條文，提出強化方向與商業效益。共 4 個 CRA 要求項目。

---

### 13.1 Annex I Sec 1(3)(d) — Unauthorized Access Protection

**CRA 要求：** 強制要求所有連接設備具備強身份驗證與唯一身份追蹤。

| 面向 | 內容 |
|------|------|
| **現有 PLANET NMS 功能** | Software-Defined Device Identity：標準軟體層簽發的 cryptographic certificate、API keys、OS 層管理的 credentials |
| **提案強化方向** | **Hardware-Rooted Identity（CRA Trust Anchor）**：佈建 TWCA-bound identity certificate，透過 cryptographic 綁定鎖入 ARM TrustZone，建立不可竄改的唯一設備識別碼 |
| **商業與安全效益** | **Zero-Identity Theft Risk**：不同於可被 OS-level 漏洞複製或外洩的軟體金鑰，hardware-bound identity 無法被複製或偽造，保證完整的 supply chain 追蹤與不可否認性 |

---

### 13.2 Annex I Sec 1(3)(e) — Data Confidentiality

**CRA 要求：** 要求使用當代技術水準的加密機制，保護傳輸中資料與遠端連線。

| 面向 | 內容 |
|------|------|
| **現有 PLANET NMS 功能** | Standard Network Layer VPNs：內建軟體 VPN（IPSec、OpenVPN、SSL VPN），在主作業系統環境中執行 |
| **提案強化方向** | **Hardware-Bound VPN（Cryptographic Hardening）**：將 private session key 直接錨定在 secure element 或 ARM TrustZone 內，強化通訊安全 |
| **商業與安全效益** | **Breach Isolation**：即使攻擊者取得主 OS 或 network stack 的完整 root 存取，private cryptographic key 仍完全無法取得，遠端管理通道持續受到保護 |

---

### 13.3 Annex I Sec 2(1) — Vulnerability Management & SBOM

**CRA 要求：** 要求有文件記錄的 Software Bill of Materials（SBOM），搭配驗證完整性並防止竄改的機制。

| 面向 | 內容 |
|------|------|
| **現有 PLANET NMS 功能** | Software Integrity Verification：內建 firmware 部署 pipeline 中的 cryptographic hash 驗證機制，確保系統更新成功 |
| **提案強化方向** | **Consolidated SBOM & Measured Boot Integrity**：在 build time 產生 cryptographically signed SBOM，搭配 ARM TrustZone 強制執行的 Measured Boot 序列（使用 OP-TEE / TF-A 架構） |
| **商業與安全效益** | **Active Supply Chain Enforcement**：標準方案將 SBOM 視為被動合規文件；此架構在開機時**主動執行 SBOM**。TrustZone 層實際量測系統 binary，若未授權軟體與已簽署 baseline 不符則阻擋執行 |

---

### 13.4 Annex I Sec 1(3)(f) — Tamper Proofing & Availability

**CRA 要求：** 要求對竄改、修改與資料毀損具備實體與系統性的韌性。

| 面向 | 內容 |
|------|------|
| **現有 PLANET NMS 功能** | Framework-Level Cyber Resilience：標準 process-level 網路安全框架與安全日誌，針對標準網路基礎設施部署優化 |
| **提案強化方向** | **Hardware-Enforced System Resilience**：在 silicon 層設定實體 TrustZone 記憶體控制器（TZASC / TZMA），在硬體層隔離安全進程與金鑰，使其與主 OS 完全分離 |
| **商業與安全效益** | **Immutable CRA Compliance**：將保護從被動的 software-dependent 框架轉移為主動的 hardware-level 記憶體防護，防止未授權 runtime data 存取，降低 2026-09 強制執行日期帶來的企業法律責任 |

---

### 13.5 Gary Matrix 整合摘要

| CRA 條文 | 現有 NMS | 提案強化 | 對應 Phase |
|---------|---------|---------|-----------|
| Annex I (2)(d) Unauthorized Access | Software cert / OS-layer credentials | Hardware-Rooted Identity（TWCA + TrustZone） | Phase 1 |
| Annex I (2)(e) Data Confidentiality | Software VPN（IPSec/OpenVPN） | Hardware-Bound VPN（key 鎖入 TrustZone） | Phase 2 |
| Annex I (Part II)(1) SBOM | Firmware hash verification | Signed SBOM + Measured Boot（OP-TEE/TF-A） | Phase 3 |
| Annex I (2)(f) Tamper Proofing | Process-level frameworks + logging | TrustZone TZASC/TZMA memory isolation | Phase 3 |

> **與 FiduciaEdge 三階段提案的對應：** Gary 的矩陣從 PLANET NMS 產品視角出發，與 FiduciaEdge 三階段 RA 提案在技術方向上高度一致。(2)(d) 對應 Phase 1、(2)(e) 對應 Phase 2、(Part II)(1) 與 (2)(f) 對應 Phase 3。差異在於 Gary 矩陣聚焦 PLANET NMS 既有功能的 gap，FiduciaEdge 提案聚焦在 TTPS DI 移植與 RA infrastructure 的具體交付。

---

---

## 14. PLANET 三階段技術提案時程（GG2 EF1）

**來源：** `PLANET_Technical_Proposal_Complete (GG2 EF1).docx` — Jerry Yang (FE) 草擬，Gary Gan (FE) 技術評審後定稿。

> 各 Phase 標示時間為假設**循序執行**的工程任務總和。許多任務可並行，以此為上限參考。Pre-requisite 項目為 PLANET 端須先備妥的條件，不在 FiduciaEdge 交付範圍內。

### 14.0 時程總覽

| Phase | 名稱 | 估算時程（循序上限） | 主要交付 | CRA 對應 |
|-------|------|---------------------|---------|---------|
| Phase 1 | Hardware-Bound Device Identity | **10w** | fTPM TA + TWCA provisioning CLI | Annex I §1(3)(d) |
| Phase 2 | Hardware-Bound VPN mTLS | **9w** | PKCS#11/TPM2 Provider + mTLS + benchmark report | Annex I §1(3)(e) |
| Phase 3 | Remote Attestation + SBOM Verification | **25w** | Measured Boot patches + RA client + Attestor service + web UI | Annex I Part II §1 + §1(3)(d)(f) |

---

### 14.1 Phase 1：安全身份佈建 [10w]

**Objective：** 將硬體綁定的設備身份與憑證佈建到矽晶層，讓應用程式可密碼學驗明設備身份。

**Outcome：** 不可偽造、hardware-bound、密碼學不可否認的設備身份。私鑰在 ARM TrustZone 內產生且永不外露，對應 CRA Annex I §1(3)(d)。

**Engineering Tasks：**

| 任務 | 估算 | 說明 |
|------|------|------|
| Initialize HRoT on ARM TrustZone | 6w | 部署 fTPM TA，暴露 TPM 2.0 API 至 OpenWRT |
| TWCA Device Identity Provisioning Pipeline | 4w | 製造端 toolchain，enclave 內產生 keypair + TWCA 憑證鎖入 secure storage |

**Pre-requisite：** MTK BSP 須已含 TF-A。若未設定，加 **3w Lead Time**。

**Out of Scope：** 整合 PLANET 客製 BSP 產品分支（約 3w）、OpenWRT GUI 管理介面。

---

### 14.2 Phase 2：硬體綁定 VPN 強化 [9w]

**Objective：** 在專用網路切片上建立獨立加密通道，完全隔離管理平面與資料流量。

**Outcome：** 即便主機 OS 被入侵，管理通道仍安全。VPN 私鑰鎖在 TrustZone 內，無法被 root 用戶讀取或提取。對應 CRA 資料機密性要求。

**Engineering Tasks：**

| 任務 | 估算 | 說明 |
|------|------|------|
| TrustZone Crypto Key & Engine Offloading | 4w | OpenSSL TPM2 Provider / PKCS#11 橋接 VPN 引擎至 fTPM Enclave |
| mTLS Isolation Verification & Testing | 2w | 驗證 mTLS 私鑰無法被 OpenWRT root 讀出或 dump |
| Network Bandwidth & Crypto Benchmarking | 3w | 驗證 enclave crypto offload 不影響路由吞吐量 |

**Out of Scope：** OpenWRT nftables / VLAN 網路切片配置（約 2w，PLANET 端負責）。

---

### 14.3 Phase 3：Remote Attestation [25w]

**Objective：** 設備在開機序列動態量測自身執行狀態，產生 Remote Attestation Report，向 NMS 驗證服務證明完整性。

**Outcome：** 主動供應鏈驗證。每個 boot 階段 hash extend 至 TrustZone 防竄改 slot，RA Report 與 PLANET 簽署 SBOM baseline 比對。偏差 → NMS 拒絕管理平面存取 + 合規告警。支援 **2026-09-11** 起的漏洞通報義務。

**Pre-requisites（PLANET 端）：**
- Phase 1 硬體綁定設備憑證已佈建
- PLANET OpenWRT 24 build 環境可自動產生 SPDX/CycloneDX SBOM
- SBOM 以 PLANET Corporate Release Key 加密簽署（非 device fTPM）
- MTK ARM bootloader pipeline (BL2→BL32) 已設定 Secure Boot image verification

**Engineering Tasks：**

| 任務 | 估算 | 說明 |
|------|------|------|
| Measured Boot Instrumentation (BL2→BL32) | 8w | BL2-BL32 Measured Boot extension，hash extend 至 fTPM tamper-proof slot |
| OpenWRT Kernel Runtime Integrity Verification | 3w | Kernel runtime integrity hooks 接入 fTPM Enclave |
| Attestation Client & Challenge Protocol | 8w | User-space RA client daemon，從 fTPM fetch signed quote，打包 RA Report |
| Standalone Device Onboarding & Attestor Service | 6w | 網路端驗證服務，接收 RA Report、驗簽、比對 SBOM baseline、Pass/Fail 判定 |

**Quantifiable Output：**
- Firmware Measured Boot patches + kernel config recipes（OpenWRT 24 target）
- Containerized Backend Remote Attestor Verification Service
- Device Onboarding Web UI Console（Pass/Fail + binary mismatch 明細）

**Out of Scope：** PLANET 內部 CI/CD SBOM 簽署管線整合（FE 提供規格指導）、NMS 核心平台程式碼修改。

---

*本文件為內部知識整理。非法律合規聲明。正式 conformity assessment 為 OEM 製造商的責任。*
