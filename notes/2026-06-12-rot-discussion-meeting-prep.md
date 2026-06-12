# 2026-06-12 RoT 方法討論 — 會議準備素材

**日期：** 2026-06-12 下午 2:00  
**目的：** 與 John 討論 CRA Compliance Support 所需 RoT 技術路線  
**狀態：** 內部工作文件，非法律合規聲明  
**HTML 版本：** [docs/meeting-prep-2026-06-12-rot-discussion.html](../docs/meeting-prep-2026-06-12-rot-discussion.html)

---

## A. 會議目標

- 確認 CRA compliance support 的 RoT 技術路線（hTPM / fTPM / hRoT）
- 釐清 hTPM / fTPM / vTPM / hRoT 各自的角色與邊界
- 確認 Techmation TX8 為何走 Soteria hRoT API 而非 TPM API
- 確認 ARM 平台 OP-TEE fTPM 是否是主要路線
- 確認 PLANET / Legacy MIPS 的可行路線與限制
- 整理後續要補的技術文件與客戶說法

---

## B. 目前的理解（請 John 確認）

- **x86 平台：** 預設使用 hTPM（hardware TPM），走 TSS2 / OpenSSL TPM2 Provider
- **ARM + TrustZone / OP-TEE：** 使用 `optee_ftpm TA`，在 OP-TEE Secure World 執行，走相同 TPM 2.0 API
- **Techmation TX8：** 使用 Soteria hRoT，不走 TPM API，透過 Soteria vendor API 整合
- **fTPM（firmware TPM）：** 用於實體 IoT / embedded / ARM device，基於 TEE / TrustZone
- **vTPM（virtual TPM）：** 主要用於 VM / KVM / QEMU，常見實作是 swtpm
- **swtpm：** 開源軟體 TPM 模擬器，主要用於 KVM/QEMU 開發測試
- **CRA support ≠ 只做 TPM：** RoT 是技術基礎，CRA 還需要 vulnerability handling、updates、docs 等

---

## C. 核心決策圖（文字版）

```
Platform type
  ├─ x86 + hardware TPM → hTPM (TSS2 / TPM2 Provider)
  ├─ ARM + TrustZone + OP-TEE → optee_ftpm TA (fTPM, 同 TPM2 API)
  ├─ Techmation TX8 → Soteria hRoT (vendor API, 非 TPM)
  ├─ Legacy MIPS → Feasibility study → external hRoT / SE / gap analysis
  └─ VM / KVM / QEMU → vTPM / swtpm (開發測試用，不可用於生產)
```

---

## D. fTPM vs vTPM 關鍵區分

| 比較項目 | fTPM | vTPM |
|---------|------|------|
| 使用場景 | 實體 IoT / embedded / ARM device | VM / KVM / QEMU |
| 信任基礎 | TrustZone 硬體隔離 | Hypervisor 軟體 |
| 常見實作 | OP-TEE fTPM TA（MS TPM 2.0 Ref Impl） | swtpm |
| CRA 生產適用 | 是 | 否 |
| PLANET ARM gateway 適用 | 是（若有 TrustZone） | 不適合 |

**重要：** fTPM ≠ vTPM。John 特別提醒這兩者不一樣。

---

## E. TPM API vs Soteria hRoT API

- **TPM API（標準）：** TCG TPM 2.0 spec → TSS2 → OpenSSL TPM2 Provider / PKCS#11
- **Soteria hRoT API（vendor-specific）：** Techmation vendor SDK，非 TCG 標準
- TX8 不需要硬套 TPM terminology
- 只要能提供 secure key storage + device identity + firmware integrity + attestation evidence foundation，就可以作為 CRA-ready RoT foundation
- **待確認：** Soteria API 支援哪些功能（尤其 attestation quote）

---

## F. CRA Support 定位說法

**使用：** "Device Trust & Platform Security Foundation for CRA Compliance Support"  
**或：** "CRA-Ready Device Trust & Platform Security Solution"

**RoT 的角色：**
- Device identity → CRA Annex I (2)(d)
- Key protection → CRA Annex I (2)(e)
- Firmware integrity → CRA Annex I (2)(f)
- Attestation foundation → CRA Annex I (2)(f)(k)(l)

**CRA 還需要（不在 RoT 範圍）：**
- Vulnerability handling / PSIRT 程序
- Security updates pipeline
- Product risk assessment（OEM 責任）
- Conformity assessment 文件

---

## G. 會議中要問 John 的問題

1. CRA Compliance Support 的範圍是否是技術 foundation，而非 full legal compliance？
2. x86 hTPM 是否正式作為 default path？使用 discrete 還是 integrated TPM？
3. ARM 平台是否只要有 TrustZone + OP-TEE，就優先評估 OP-TEE fTPM TA？
4. OP-TEE fTPM TA 是否採用 Microsoft TPM 2.0 Reference Implementation 作為基礎？
5. Techmation TX8 的 Soteria API 已知支援哪些能力？有沒有 API spec 或 SDK？
6. Soteria hRoT 是否支援：secure key storage、device identity（non-exportable key）、firmware integrity、attestation evidence？
7. PLANET 的 MediaTek ARM gateway 是否確認有 OP-TEE / TrustZone？BSP 狀態？
8. PLANET Legacy MIPS 是否能加入 external hRoT 或 secure element？
9. Remote Attestation 是 Phase 3 roadmap，還是希望一開始提案就納入？
10. CRA Annex mapping 需要做到 requirement level 還是 solution capability level？

---

## H. 不應過度承諾

### ❌ 不可說
- 我們保證完整 CRA compliance
- 所有產品都能用 TPM
- Legacy MIPS 不改硬體也能完整 attestation
- Soteria hRoT 等於 TPM
- fTPM 等於 vTPM
- Remote Attestation 立即支援所有平台

### ✓ 正確說法
- CRA-ready · CRA compliance support · CRA readiness foundation
- RoT 選擇依平台而定；關鍵需求是 hardware-protected key mechanism
- 無 hardware RoT 的 MIPS 只能提供 gap analysis + compensating controls
- Soteria hRoT 是 vendor-specific hardware RoT，需確認其具體能力
- fTPM 用於實體 embedded；vTPM 用於 VM 環境
- Remote Attestation 是 Phase 3 roadmap，需逐平台評估

---

## I. 會議後行動項目

- [ ] 更新平台 RoT decision table（依 John 確認結果）
- [ ] 補 Soteria API capability matrix
- [ ] 補 OP-TEE fTPM feasibility checklist
- [ ] 補 PLANET product architecture checklist
- [ ] 補 CRA Annex mapping validation（對照 EUR-Lex 原文）
- [ ] 補 customer-facing one-page positioning
- [ ] 補 Microsoft TPM 2.0 Reference Implementation 說明
- [ ] 補 fTPM vs vTPM 技術區分文件

---

## 來源資料狀態

| 檔案 | 狀態 |
|------|------|
| `references/cra/Most Popular fTPM used in IoT or embedded devices (gSrchAI 26-06-10).pdf` | ⚠️ **需人工確認** — PDF 未完整解析 |
| `references/cra/Most Popular vTPM used in IoT or embedded devices (gSrchAI 26-06-10).pdf` | ⚠️ **需人工確認** — PDF 未完整解析 |
| `references/cra/OJ_L_202402847_EN_TXT.pdf` | EU CRA 官方正文，建議對照 Annex I 條文時直接參閱 |
| `references/cra/PLANET_NMS_CRA_Enforcement_Matrix (GG1).xlsx` | 已整理於 current-device-trust-cra-summary.html |

---

*維護：FiduciaEdge TTPS 團隊 · 2026-06-12*
