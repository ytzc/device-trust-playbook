# Device Trust Memory Guide

設備信任技術記憶指南：手機複習、默背與口頭說明用

**FiduciaEdge TTPS 團隊 · 內部學習用途 · CRA 2024/2847 強制執行：2027-12-11**

---

## S1 七個核心心智模型

| 模型 | 一句話 |
|------|--------|
| Device Trust | 設備身份可信 + 私鑰不外洩 + 開機可驗 + 連線可認 |
| Root of Trust (RoT) | 信任鏈的硬體起點，密鑰永不離開 |
| hTPM | x86 default，PCIe/LPC 焊接晶片，最標準 |
| fTPM | ARM TrustZone Secure World 的 TA，同 hTPM API |
| Soteria hRoT | TX8 AHB HW IP，非 TPM，vendor-specific MSG 命令 |
| OP-TEE | 主 SoC TrustZone 的 OS，**不跑在 Soteria 上** |
| CRA-ready | 技術基礎到位，full compliance 是 OEM 責任 |

---

## S2 閃卡詞彙表（27 個）

| 術語 | 一句話定義 |
|------|------------|
| Device Trust | 設備身份可信 + 私鑰不外洩 + 開機可驗 + 連線可認 |
| DevID | 設備身份憑證（IEEE 802.1AR），hardware-bound |
| IDevID | 出廠燒錄，與設備終身綁定，不可更換 |
| LDevID | 現場發放，可更換 / 可撤銷（類似工作證） |
| hTPM | Hardware TPM 2.0，x86 default，PCIe/LPC 晶片 |
| fTPM | TrustZone Secure World 裡的 TPM TA，同 hTPM API |
| vTPM | VM/QEMU 軟體模擬，僅開發測試，不能生產用 |
| hRoT | Hardware Root of Trust，vendor-specific，如 Soteria |
| Soteria | TX8 AHB HW IP，RISC-V ibex，8KB OTP，10 個 MSG 命令 |
| OP-TEE | ARM TrustZone Secure World OS，不跑在 Soteria 上 |
| fTPM TA | 跑在 OP-TEE 裡的 Trusted Application |
| SE | Secure Element，外接安全晶片（I2C/SPI/USB） |
| PUF | Physical Unclonable Function，設備唯一 fingerprint |
| Secure Boot | 驗簽，失敗不開機（守門員） |
| Measured Boot | 量測 hash → PCR，允許開機留記錄（記錄員） |
| Remote Attestation | 簽名 PCR 傳 Verifier（報告員） |
| mTLS | 雙向 TLS，設備用 DevID 私鑰做 client auth |
| CRA-ready | 技術控制到位，可準備 evidence，非 full compliance |
| Black Key | TRNG + ROK 加密 → ENZMK+ENBK+MAC，HUK 不離 Soteria |
| HUK | Hardware Unique Key，設備唯一根密鑰，永不外洩 |
| ROK | Root of Key，Soteria OTP 存儲，INSTALL_ROK 安裝 |
| OTP | One-Time Programmable，8KB，一次寫入不可更改 |
| TSS2 | TPM Software Stack 2.0，標準 TPM API |
| PCR | Platform Configuration Register，存 hash 記錄 |
| AIK | Attestation Identity Key，TPM Quote 簽名金鑰 |
| BRSKI | RFC 8995，零觸碰自動上線，用 IDevID 取得 LDevID |
| TTPS DI | FiduciaEdge 的 Trusted Third-Party Service - Device Identity 模組 |

---

## S3 TPM 類型比較

| 類型 | 位置 | 記憶 | 生產用？ |
|------|------|------|---------|
| hTPM | 主板晶片（PCIe/LPC） | 最標準，x86 default | ✅ |
| fTPM | ARM TrustZone SW（OP-TEE TA） | 無額外晶片，軟體化 | ✅ |
| vTPM | KVM/QEMU 模擬 | 開發/CI 用 | ❌ |
| OP-TEE fTPM | 同 fTPM（OP-TEE 裡的 TA） | fTPM ≠ vTPM | ✅（若平台就緒） |
| Soteria hRoT | AHB HW IP（非 TPM） | 非標準，TX8 專屬 | ✅ |
| SE | 外接晶片（I2C/SPI） | Legacy 補強用 | ✅ |
| PUF | 晶片製造差異 fingerprint | Key derivation 基礎 | ✅（搭配用） |

**口訣：fTPM 是真實 ARM 設備的 TrustZone TA；vTPM 是 VM 模擬。絕對不混用。**

---

## S4 平台決策

| 平台 | RoT 選擇 | 說明 |
|------|---------|------|
| x86 / Server | hTPM | 最標準，Phase 1/2/3 全支援 |
| ARM + TrustZone | OP-TEE fTPM | 確認 TF-A + OP-TEE + fTPM TA 存在 |
| TX8（Soteria） | Soteria-native（優先）/ OP-TEE fTPM（TBC） | TrustZone 未確認，先研究 Soteria-native |
| Legacy MIPS | feasibility study | 確認能否加 external SE/hRoT |
| VM/QEMU | vTPM（swtpm） | 僅 CI/CD 測試，不可生產 |
| ARM 無 TrustZone | External SE / feasibility | 評估補強方案 |
| i.MX93 | NXP ELE + EL2GO | EdgeLock 生態系 |

**口訣：x86 找 hTPM，ARM 看 OP-TEE，TX8 先看 Soteria，MIPS 先 feasibility，VM 才談 vTPM。**

---

## S5 Soteria-native Path

### 製造 → 部署 → 運行

1. **Factory**：INSTALL_ROK（0x11）燒 OTP，鎖 debug
2. **Key Gen**：TRNG → Black Key（non-exportable ⚠️TBC）
3. **CSR**：SW 層 ASN.1 + Soteria RSA 簽名（0x3）→ CA → IDevID cert
4. **Cert 儲存**：key → OTP；cert → flash + Black Key 保護（⚠️TBC）
5. **mTLS**：Soteria RSA 做 TLS client auth（⚠️TBC workflow）
6. **Future**：Soteria attestation quote（❌TBC）

### 能力狀態

- ✅ 確認：TRNG、RSA 2048 簽名、AES、HMAC、OTP/HUK/ROK、Secure Boot（0x15/0x16）、Anti-rollback（0x17）
- ⚠️ TBC：Non-exportable key、公鑰導出、Black Key、X.509 cert 儲存、ECDSA、Debug lock
- ❌ TBC：Firmware measurement、Attestation quote、Monotonic counter

### Soteria MSG 命令速記

| MSG0 | 命令 | 用途 |
|------|------|------|
| 0x1 | AES | 對稱加密 128/192/256-bit |
| 0x2 | HMAC | SHA-256/384/512 完整性驗證 |
| 0x3 | RSA | **非對稱簽名 2048-bit — DevID / mTLS** |
| 0x4 | TRNG | **真亂數 — Key 生成基礎** |
| 0x11 | INSTALL_ROK | **Root of Key 安裝 — 製造端入口** |
| 0x12 | CREATE_BK | Black Key 生成（TRNG + ROK 加密） |
| 0x14 | AES_BK | Black Key 透明 AES |
| 0x15 | KEY_HASH_CHK | Secure Boot：image hash vs OTP pubkey |
| 0x16 | RSA_OTP | Secure Boot：RSA 驗簽 |
| 0x17 | BOOT_IMG_ID | Anti-rollback |

---

## S6 OP-TEE fTPM

- OP-TEE 跑在主 ARM SoC TrustZone **Secure World**，**不跑在 Soteria**
- fTPM TA = OP-TEE 裡的 Trusted Application（基於 MS TPM 2.0 Reference Impl.）
- 對外看起來和 hTPM 一樣：`/dev/tpmX` → tpm2-abrmd → TSS2 → OpenSSL TPM2 Provider
- TX8 前提：TrustZone + TF-A（BL31）+ OP-TEE OS（BL32）+ fTPM TA → **全部未確認**
- John 擔心：Memory footprint 4–16 MB + 四層 BSP 整合成本

---

## S7 Soteria-native vs OP-TEE fTPM 比較

| 維度 | Soteria-native | OP-TEE fTPM |
|------|----------------|-------------|
| TX8 前提 | AHB driver ✅ | TrustZone ⚠️未確認 |
| 記憶體 | 低 | 高（4–16 MB） |
| ECDSA | ❌TBC | ✅ |
| Non-exportable key | Black Key ⚠️TBC | TPM binding ✅ |
| mTLS 整合 | ⚠️TBC | ✅ OpenSSL |
| TSS2 相容 | ❌ | ✅ |
| PCR / Attestation | ❌TBC | ✅ |
| CRA Phase 3 | ❌TBC | ✅ |
| Speed to PoC | 較快 | 較慢 |

**說法：短期先研究 Soteria-native，客戶需 TPM evidence 或 Phase 3 RA 再評估 fTPM；設計保持 backend-agnostic。**

---

## S8 開機完整性階梯

| 概念 | 做什麼 | 阻擋開機？ | Evidence | 記憶 |
|------|--------|------------|----------|------|
| Secure Boot | 驗簽，拒絕未授權 image | ✅ 會 | Pass/Fail | 守門員 |
| Measured Boot | 量測 hash → PCR | ❌ 不 | PCR 0–23 | 記錄員 |
| Remote Attestation | 簽名 PCR 傳 Verifier | ❌ 不 | TPM2_Quote | 報告員 |

**TX8 現況：Secure Boot ✅；Measured Boot / RA 均 ❌TBC**

**口訣：Secure Boot 擋，Measured Boot 記，Remote Attestation 報。**

---

## S9 設備生命週期

1. **Device Initialization** — 燒 RoT keys / OTP，設定 Secure Boot，鎖 debug
2. **Secure Provisioning** — 安全安裝 credentials / cert / config
3. **Device Registration** — 第一次向後端登記身份
4. **Device Onboarding** — 完成認證取得網路存取（BRSKI / FDO）
5. **mTLS Secure Communication** — 雙向認證連線
6. **Firmware Update** — 簽名保護 + anti-rollback
7. **Measured Boot** — 開機量測 PCR
8. **Remote Attestation** — NMS 定期驗證
9. **CRA Evidence** — 彙整技術 evidence 支援合規評估

---

## S10 CRA-ready vs Full Compliance

### 應該說 ✅

- CRA-ready technical foundation
- CRA compliance support / evidence preparation
- hardware-protected key mechanism
- Remote Attestation is a roadmap

### 不能說 ❌

- guarantee full CRA compliance
- Soteria automatically satisfies CRA
- fTPM = vTPM
- Soteria = TPM
- OP-TEE runs on Soteria
- Soteria 已確認支援所有 DevID 能力

### 法律責任邊界

Conformity assessment / CE marking 責任在 **OEM 製造商**。FiduciaEdge 提供技術服務與 evidence 準備，不承擔 OEM 合規法律責任。

---

## S11 客戶案例

### PLANET Technology

- **高階 ARM gateway** → OP-TEE fTPM → Zero Trust → RA roadmap（三階段）
- **Legacy MIPS** → feasibility study → 評估 external SE/hRoT → Gap Analysis

### Techmation TX8

- 已有 Soteria hRoT（AHB-connected）
- 主研究：Soteria-native DevID path（TrustZone 待確認）
- P0 問題：ECDSA / non-exportable key / TrustZone 支援

### x86 / Server → hTPM（最標準）

### ARM Embedded → OP-TEE fTPM（確認 TrustZone）

### Legacy MIPS → feasibility study（不亂承諾 hardware RoT / RA）

---

## S12 口頭問答 30 題（精簡版）

1. **fTPM vs vTPM**：fTPM 是實體 TrustZone TA；vTPM 是 VM 模擬，僅測試用
2. **Soteria 不是 TPM**：vendor-specific AHB MSG 命令，無 TSS2 API
3. **OP-TEE 跑哪**：主 SoC TrustZone，Soteria 是被 OP-TEE 存取的 AHB HW
4. **IDevID vs LDevID**：出廠終身綁定 vs 現場可換可撤銷
5. **mTLS + DevID**：私鑰在硬體內做簽名，不外洩
6. **Secure Boot vs Measured Boot**：擋 vs 記
7. **Measured Boot vs RA**：本地 PCR vs 簽名傳 Verifier
8. **CRA-ready vs full compliance**：技術基礎 vs OEM 的合規責任
9. **何時需要 fTPM**：需要 TSS2 / PCR / TPM2_Quote / ECDSA
10. **TX8 為何先 Soteria-native**：TrustZone 未確認，記憶體佔用低
11. **Device Trust Abstraction Layer**：backend-agnostic 介面，`dt_generate_key` 等 5 個 API
12. **Black Key**：TRNG → ROK 加密 → ENZMK+ENBK+MAC，HUK 不離 Soteria
13. **Non-exportable key 為何重要**：802.1AR 要求，防私鑰複製
14. **Soteria CSR**：SW 層 ASN.1 + Soteria RSA 簽名
15. **PLANET 切入**：ARM 談 fTPM；MIPS 先 feasibility
16. **TX8 切入說法**：先 Soteria-native，TrustZone 確認再談 fTPM，保持 backend-agnostic
17. **MIPS 可做 RA？**：不能承諾，無 hardware RoT 就無 PCR/Quote
18. **Phase 1/2/3**：DevID/mTLS → Provisioning/Onboarding → Measured Boot/RA
19. **為何 backend-agnostic**：不同客戶不同 RoT，未來換後端不重寫上層
20. **SE 適合什麼**：Legacy 補強，Phase 1/2 可行，Phase 3 需另確認
21. **PUF**：晶片製造差異 fingerprint，key derivation 基礎
22. **IEEE 802.1AR**：DevID 標準，non-exportable key / IDevID / LDevID
23. **BRSKI**：RFC 8995，IDevID 認證取得 LDevID，零觸碰上線
24. **CRA 強制執行日 + 罰款**：2027-12-11；€15M 或年營收 2.5%
25. **向外人解釋 Soteria**：TX8 內建 HW 安全模組，類似 TPM，AHB 存取，RISC-V + OTP
26. **HUK**：設備唯一根密鑰，TRNG 生成存 OTP，永不離開 Soteria
27. **John 擔心 OP-TEE 記憶體**：4–16 MB，嵌入式資源緊張，若只需 DevID 不值得
28. **INSTALL_ROK**：製造端安裝 ROK 到 OTP，Black Key 機制的根
29. **swtpm 怎麼用**：CI/CD 測試用 vTPM 模擬，不可生產
30. **三條鐵律**：① 不說 full CRA compliance ② fTPM≠vTPM ③ OP-TEE 不跑在 Soteria

---

## S13 一頁速記 5×5

### 5 個核心觀念

1. Device Trust = 身份可信 + 私鑰不外洩 + 開機可驗 + 連線可認
2. RoT 是信任鏈起點，不等於 CRA compliance
3. fTPM ≠ vTPM（實體 TEE vs VM 模擬）
4. OP-TEE 跑在主 SoC，不跑在 Soteria
5. Secure Boot 擋 → Measured Boot 記 → RA 報

### 5 個重要決策

1. x86 → hTPM
2. ARM + TrustZone → OP-TEE fTPM
3. TX8 → 先 Soteria-native，再評估 fTPM
4. Legacy MIPS → feasibility study first
5. 設計用 Device Trust Abstraction Layer，backend-agnostic

### 5 個不要講錯

1. 不說 guarantee full CRA compliance
2. 不說 fTPM = vTPM
3. 不說 OP-TEE 跑在 Soteria 上
4. 不說 Soteria = TPM
5. 不說 Soteria 已確認支援所有 DevID 能力

### 5 個要問客戶

1. SoC 型號？有 ARM TrustZone？
2. BSP 有 TF-A + OP-TEE？已啟用？
3. 需要 TPM 2.0 API 相容（TSS2）？
4. Remote Attestation 是近期還是 Phase 3？
5. CRA 2027-12-11 前有多少時間？

### 5 個未來 Roadmap

1. Soteria attestation quote（❌TBC — Phase 3 關鍵）
2. Device Trust Abstraction Layer 實作（2026 Q3–Q4）
3. ECDSA 支援（Soteria ❌TBC，fTPM ✅）
4. OP-TEE fTPM on TX8（若 TrustZone 確認）
5. CRA Annex I evidence 彙整 pipeline（2027 前）

---

## 最終三口訣

> 「x86 找 hTPM，ARM 看 OP-TEE，TX8 先看 Soteria，MIPS 先 feasibility，VM 才用 vTPM。」

> 「Secure Boot 擋，Measured Boot 記，Remote Attestation 報。」

> 「CRA-ready 是技術基礎，full compliance 是 OEM 的責任。」
