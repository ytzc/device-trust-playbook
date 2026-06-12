# Platform Solution Decision Map

**最後更新：** 2026-06-12  
**狀態：** 內部工作筆記  
**HTML 版本：** [docs/platform-solution-decision-map.html](../docs/platform-solution-decision-map.html)  
**來源：** John 2026-06-10 技術方向討論

---

## 核心原則

- **三階段 RA 可行性由 hardware root-of-trust capability 決定，不由處理器架構名稱決定**
- MIPS 架構本身不是阻礙——問題在於特定 MIPS SoC 是否缺乏 hardware RoT
- PKCS#11 ≠ 完整 Remote Attestation（PKCS#11 只解決 key operations，不提供 Measured Boot / PCR）

---

## 決策路線總覽

### Path X86：x86 + hTPM（Default Path）

- **RoT：** hardware TPM 2.0（discrete 或 integrated）
- **API：** TSS2 / OpenSSL TPM2 Provider / tpm2-pkcs11
- **三階段：** 完整適用（Phase 1/2/3）
- **狀態：** 已驗證（TTPS DI 在 Ubuntu + hTPM 驗證）
- **優先使用：** x86 PC / Server 平台

### Path ARM-A：ARM + TrustZone + OP-TEE fTPM（主要交付目標）

- **RoT：** optee_ftpm TA（執行於 OP-TEE Secure World，通常基於 MS TPM 2.0 Ref Impl）
- **API：** 相同的 TSS2 / TPM2 Provider（對上層透明）
- **三階段：** 完整適用（Phase 1/2/3）
- **前置條件：** BSP 含 TF-A + OP-TEE OS + fTPM TA；Secure Boot 啟用
- **PLANET 適用性：** MediaTek ARM gateway 的主要路線
- **Phase 1 工程重點：** TTPS DI 移植（Ubuntu+TPM → MTK OpenWRT + OP-TEE fTPM）

### Path ARM-B：ARM TrustZone 存在但 BSP 未啟用

- **狀態：** 需先啟用 OP-TEE + fTPM TA，完成後等同 Path ARM-A
- **工程：** BSP 評估 + TF-A / OP-TEE 啟用（+3w Lead Time 如 MTK BSP 未設定）

### Path TX8：Techmation TX8 — 三種可能路線

**研究方向更新（2026-06-12）：** 主要研究軸心從「OP-TEE fTPM 可行性」改為「Soteria-native DevID & Provisioning vs OP-TEE fTPM」。John 的擔憂：OP-TEE 記憶體佔用大、整合成本高、如果只需要 DevID/mTLS 不需要完整 fTPM。

**Primary research：Soteria-native DevID Path**

- **RoT：** Soteria hRoT（AHB-connected HW IP，非 TPM）
- **Soteria 元件：** RISC-V ibex processor + 8KB OTP + AES/HMAC/RSA/TRNG 加速器
- **研究問題：** Soteria 能否直接支援 DevID / mTLS / provisioning（不依賴 OP-TEE fTPM）？
- **已確認：** RSA (0x3) / HMAC (0x2) / AES (0x1) / TRNG (0x4) / Black Key (0x12/0x14) / OTP / Secure Boot anchor
- **TBC：** ECDSA 支援、non-exportable key gen API、cert 儲存方案（OTP 8KB 限制）、mTLS 工作流程
- **未來擴展：** Firmware measurement / attestation quote（❌ TBC；CRA Phase 3 阻擋條件）
- **設計目標：** Device Trust Abstraction Layer（backend-agnostic，未來可切換 OP-TEE fTPM 後端）

**Candidate path：OP-TEE fTPM（若 TX8 SoC 支援 TrustZone）**

- **前提：** TX8 main SoC 支援 ARM TrustZone + BSP 含 TF-A + OP-TEE OS + fTPM TA
- **TX8 SoC 型號 / TrustZone 支援：** ⚠️ 未確認
- **API：** 相同的 TSS2 / TPM2 Provider（標準 TPM 2.0）
- **優勢：** TTPS DI 可直接移植，完整 PCR / attestation 支援

**Hybrid candidate：OP-TEE fTPM + Soteria hRoT-backed storage（研究方向）**

- OP-TEE fTPM 提供 TPM API；Soteria hRoT 作為底層硬體 key protection 加固
- 整合複雜度最高；目前為研究 candidate
- 需確認 Soteria 是否在 TrustZone Secure World 可見

詳細分析：[notes/techmation-tx8-soteria-optee-ftpm-analysis.md](./techmation-tx8-soteria-optee-ftpm-analysis.md)  
DevID 能力調查：[notes/soteria-native-device-identity-provisioning-survey.md](./soteria-native-device-identity-provisioning-survey.md)

### Path SE：任意平台 + External SE + PKCS#11

- **RoT：** External Secure Element
- **API：** PKCS#11 標準
- **Phase 1/2：** 可行
- **Phase 3：** 需另確認 Measured Boot 能力（SE 通常不支援）
- **適用：** Legacy 平台補強選項

### Path MIPS：Legacy MIPS（無 hardware RoT）

- **狀態：** 先做 feasibility study，評估能否加入 external hRoT / SE
- **無法加入：** Gap Analysis + compensating controls only
- **不可承諾：** hardware-bound identity、non-exportable key、Remote Attestation

### Path VM：VM / KVM / QEMU

- **RoT：** vTPM / swtpm
- **用途：** 開發測試
- **限制：** 不可用於生產設備（信任基礎是 hypervisor）

---

## 決策表

| 平台 | 推薦 RoT | TPM? | API | Phase 1 | Phase 2 | Phase 3 | CRA-ready |
|------|---------|------|-----|---------|---------|---------|---------|
| x86 | hTPM | TPM 2.0 | TSS2 / TPM2 Provider | ✅ | ✅ | ✅ | 強 |
| ARM + OP-TEE | fTPM TA | fTPM | TSS2 / TPM2 Provider | ✅ | ✅ | ✅ | 強 |
| TX8 (Path A) | Soteria hRoT API | 非 TPM | Soteria vendor SDK | ✅ | ✅ | ⚠️ TBD | 中 |
| TX8 (Path B) | OP-TEE fTPM（若支援 TZ） | fTPM | TSS2 / TPM2 Provider | ⚠️ TZ待確認 | ⚠️ | ⚠️ | 強（若就緒） |
| TX8 (Path C) | Hybrid fTPM + Soteria | fTPM + hRoT | TSS2 + Soteria API | 🔬 研究中 | 🔬 | 🔬 | 最強（若可行） |
| Legacy MIPS | 先 feasibility study | 無 | — | ❌ | ❌ | ❌ | 有限 |
| VM / KVM | vTPM / swtpm | vTPM | TPM2 Provider | 測試 | 測試 | 測試 | 不可生產 |

---

## 風險與待確認

| 路線 | 風險 / 待確認 | 緊急程度 |
|------|-------------|---------|
| ARM-A/B | MTK BSP OP-TEE + fTPM TA 就緒狀態；Secure Boot | Critical |
| TX8 Path A | Soteria API attestation quote / PCR support | Critical |
| TX8 Path A | Soteria SDK 文件；custom adapter 工程量 | High |
| TX8 Path B | TX8 main SoC 型號；是否支援 ARM TrustZone；BSP TF-A + OP-TEE 狀態 | Critical |
| TX8 Path C | Soteria hRoT 是否在 TrustZone Secure World 可見；OP-TEE storage backend | Medium（研究） |
| MIPS | 各型號 SoC 清單；external SE 接頭存在 | High |
| ARM-A | MS TPM 2.0 Reference Impl 版本與 OP-TEE 整合狀態 | Medium |

---

## 相關頁面

- [docs/rot-methods-comparison.html](../docs/rot-methods-comparison.html)
- [docs/planet-analysis.html](../docs/planet-analysis.html)
- [notes/rot-methods-comparison.md](./rot-methods-comparison.md)

---

*維護：FiduciaEdge TTPS 團隊 · 2026-06-12*
