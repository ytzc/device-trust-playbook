# RoT Methods Comparison

**最後更新：** 2026-06-12  
**狀態：** 內部工作筆記  
**HTML 版本：** [docs/rot-methods-comparison.html](../docs/rot-methods-comparison.html)

---

## 方法一覽

### hTPM（Hardware TPM）

- 實體 TPM 2.0 晶片（discrete 或 integrated）
- x86 平台標準方案
- Discrete 例子：Infineon SLB9670 / STM33
- Integrated：Intel PTT（Platform Trust Technology）/ AMD PSP fTPM
- API：TSS2 → OpenSSL TPM2 Provider / tpm2-pkcs11
- 特色：最強硬體隔離，PCR 0–23，完整 attestation quote 支援

### fTPM（Firmware TPM）

- 在 TEE（ARM TrustZone / OP-TEE Secure World）中執行的 TPM firmware 實作
- ARM 平台主要路線
- 信任基礎：TrustZone 硬體記憶體隔離（TZASC）
- 對外提供標準 TPM 2.0 API（同 hTPM，TSS2 / TPM2 Provider）
- 常見實作：OP-TEE fTPM TA（通常基於 Microsoft TPM 2.0 Reference Implementation）
- **⚠️ fTPM ≠ vTPM**

### vTPM（Virtual TPM）

- 在 VM / hypervisor 環境中的虛擬化 TPM
- 信任基礎：hypervisor 軟體
- 常見實作：swtpm
- 用途：開發測試 / CI pipeline
- **不可用於生產 embedded 設備**

### hRoT（Hardware Root of Trust）

- 專用硬體安全模組，提供 hardware-isolated key protection
- 例子：Soteria hRoT（TX8）、NXP ELE（EdgeLock Secure Enclave）
- API：通常是 vendor-specific SDK（非 TCG 標準）
- 適用：有 dedicated security chip 但沒有 TPM 的設備

### Secure Element（SE）

- 可加入現有平台的外接安全晶片
- 介面：I2C / SPI / USB
- API：PKCS#11 標準（跨廠商通用）
- 適合：Legacy 平台補強（加裝 SE）
- 限制：通常不支援 Measured Boot / PCR / attestation quote

### PUF（Physical Unclonable Function）

- 利用晶片製造差異產生唯一 fingerprint（device-specific root secret）
- 用途：key derivation 基礎（衍生不可複製的 device key）
- 部分 SoC 內建（如 NXP ELE 內建 PUF）
- 不直接提供 TPM 功能，需搭配上層 key management

### Pure Software Key Storage（不建議）

- Key 存在 OS 檔案系統，無硬體保護
- OS root 可讀取 / 複製 key
- 只適合開發環境
- **不應用於 CRA production 設備**

---

## fTPM vs vTPM 關鍵區分

**John 特別強調：這兩者完全不同，不要混用。**

| 比較項目 | fTPM（Firmware TPM） | vTPM（Virtual TPM） |
|---------|-------------------|------------------|
| 使用場景 | 實體 IoT / embedded / ARM device | VM / KVM / QEMU |
| 執行環境 | TrustZone Secure World（firmware） | Hypervisor / QEMU 模擬器 |
| 硬體隔離 | TrustZone TZASC 硬體記憶體隔離 | 無實體隔離 |
| 常見實作 | OP-TEE fTPM TA | swtpm |
| TPM 2.0 API | 是（TSS2 完整相容） | 是（相同 API） |
| Key 保護強度 | 強（TZ 隔離） | 依 hypervisor |
| CRA 生產適用 | 是 | 否 |
| PCR / Measured Boot | 是 | 是（可信度有限） |
| PLANET ARM gateway | 是 | 不適合 |

---

## OP-TEE fTPM TA 技術細節

- ARM TrustZone + OP-TEE Secure World 架構
- 通常基於 **Microsoft TPM 2.0 Reference Implementation**（microsoft/ms-tpm-20-ref）
- 對 Normal World 透過 TEE Client API 通訊
- Normal World 使用 TSS2，感覺不到是 fTPM 還是 hTPM
- 儲存：OP-TEE Secure Storage（hardware-protected key 加密）
- 需要：TF-A（Trusted Firmware-A） + OP-TEE OS + fTPM TA

### BSP 前置條件（PLANET ARM gateway）

1. MTK SoC BSP 含 TF-A（BL1/BL2/BL31）
2. OP-TEE OS（BL32）啟用
3. fTPM TA 編譯並加入 OP-TEE build
4. Secure Boot 啟用（Phase 3 前提）
5. tpm2-abrmd daemon（Linux TPM Resource Manager）

---

## Microsoft TPM 2.0 Reference Implementation

- GitHub: `microsoft/ms-tpm-20-ref`
- 符合 TCG TPM 2.0 Part 1–4 specification
- C 語言，可移植到各種 TEE / firmware 環境
- 是 OP-TEE fTPM TA 的常見基礎實作
- AMD PSP fTPM 也基於此（部分版本）
- **⚠️ 需確認：** PLANET 的 OP-TEE fTPM 版本與 MS Ref Impl 基礎關係

---

## swtpm 技術細節

- 開源軟體 TPM 2.0 模擬器（Stefan Berger / IBM）
- GitHub: `stefanberger/swtpm`
- KVM / QEMU 整合：`-tpmdev emulator,id=tpm0,chardev=chrtpm`
- Guest OS 透過 `tpm-tis-device` 存取，與實體 TPM 相同 API
- **FiduciaEdge 使用場景：** CI/CD pipeline 測試，不是交付 production 設備
- **限制：** TPM state 存在 host 檔案系統，host OS / hypervisor 可讀取

---

## Soteria hRoT（TX8）

- Techmation TX8 的 hardware RoT 模組
- **AHB memory-mapped IP**（非 TCG TPM 2.0 標準）
- 內部：RISC-V ibex processor + 8KB OTP + AES/HMAC/RSA/TRNG 加速器
- AHB Slave Port：MSG0–MSG15（`0x00–0x3C`）+ Control（`0x40–0x60`）
- 透過 Secure World-only AHB driver 存取；bus isolation（TZASC/PMP）確保 Normal World 無法存取
- Phase 1/2 技術上可行（需 custom adapter）
- **Phase 3 阻擋條件：** Soteria 是否支援 attestation quote / PCR-like measurement
- **正確說法：** 「TX8 的 hardware RoT 是 Soteria hRoT，透過 AHB interface 由 OP-TEE Secure World 存取」
- **錯誤說法：** 「TX8 的 TPM 是 Soteria」 / 「OP-TEE 跑在 Soteria 上」

### Soteria 主要命令（2026-06-12 新增）

| 命令 | MSG0 | 功能 |
|------|------|------|
| AES | 0x1 | 對稱加密（128/192/256-bit，ECB/CBC/CTR） |
| HMAC | 0x2 | 雜湊 / MAC（SHA-256/384/512，SHA3-512，MD5） |
| RSA | 0x3 | 非對稱加密（512/1024/2048-bit，PKCS#1 v1.5） |
| TRNG | 0x4 | 真亂數生成 |
| INSTALL_ROK | 0x11 | Root of Key 安裝 / 認證 |
| CREATE_BK | 0x12 | 生成 Black Key（TRNG + ROK 加密） |
| AES_BK | 0x14 | Black Key 透明 AES（raw HUK 不離開 Soteria） |
| KEY_HASH_CHK | 0x15 | Secure Boot：image hash vs OTP pubkey hash |
| RSA_OTP | 0x16 | Secure Boot：RSA 簽章驗證（OTP pubkey） |
| BOOT_IMG_ID | 0x17 | Anti-rollback / active boot image 查詢 |

### TX8 的三種整合路線（2026-06-12 新增分析）

TX8 目前 primary known path 是 Soteria hRoT API，但需進一步評估：

| 路線 | 說明 | 前提條件 | 狀態 |
|------|------|---------|------|
| **Path A：Soteria API Only** | 直接透過 Soteria vendor API 整合，不使用 TPM API | 取得 Soteria SDK | ⚠️ Soteria API 能力待確認 |
| **Path B：OP-TEE fTPM Only** | 若 TX8 SoC 支援 TrustZone，跑 OP-TEE fTPM TA | TX8 SoC 支援 TrustZone + BSP OP-TEE 就緒 | ⚠️ TX8 TrustZone 未確認 |
| **Path C：Hybrid** | OP-TEE fTPM + Soteria hRoT-backed storage | Path B 前提 + Soteria Secure World 可見 | 🔬 研究 candidate |

**⚠️ 重要：OP-TEE 跑在主 ARM SoC TrustZone Secure World，不是跑在 Soteria hRoT 上。**

詳細分析請見：[notes/techmation-tx8-soteria-optee-ftpm-analysis.md](./techmation-tx8-soteria-optee-ftpm-analysis.md)

---

## RoT 在 CRA Support 中的角色

RoT 是 CRA compliance support 的技術基礎，不等於完整 CRA compliance。

| CRA 要求 | RoT 提供的技術基礎 | CRA Annex I |
|---------|-----------------|------------|
| Device Identity | Hardware-bound IDevID/LDevID | (2)(d) |
| Key Protection | Non-exportable key in hardware boundary | (2)(e) |
| Firmware Integrity | Secure Boot + Measured Boot + PCR | (2)(f) |
| Attestation | Signed attestation quote | (2)(f)(k)(l) |

CRA 還需要（不在 RoT 範圍）：
- Vulnerability handling / PSIRT 程序
- Security updates pipeline
- Product risk assessment（OEM 責任）
- Conformity assessment（OEM 責任）

---

*維護：FiduciaEdge TTPS 團隊 · 2026-06-12*
