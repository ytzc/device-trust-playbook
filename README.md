# Device Trust & Platform Security Playbook

設備信任、Root of Trust、安全佈建、設備上線、韌體完整性、Remote Attestation，以及 CRA-ready 產品安全的技術作戰手冊。

---

## 用途

本 repo 是 FiduciaEdge 的長期技術知識庫，涵蓋：

- **Device Identity** — IDevID / LDevID，hardware-bound，non-exportable private key，mTLS-ready device identity
- **Root of Trust** — TPM 2.0 / fTPM / hTPM / Soteria hRoT / External SE / PUF
- **Soteria-native Device Identity** — TX8 Soteria hRoT 直接支援 DevID / provisioning / mTLS 能力調查；與 OP-TEE fTPM 路線比較
- **Secure Provisioning & Onboarding** — TTPS DI、FDO（FIDO Device Onboard）、zero-touch provisioning
- **Firmware Integrity** — Secure Boot、Measured Boot、SBOM
- **Remote Attestation** — Measured Boot evidence、signed report、NMS policy engine
- **CRA Readiness** — EU CRA 2024/2847 Annex I 技術控制對應、evidence preparation、conformity assessment support
- **Backend-agnostic Device Trust Abstraction Layer** — 統一支援 Soteria / TPM / fTPM / OP-TEE 等不同 RoT 後端的抽象設計

> **CRA 全面強制執行日：2027-12-11**

---

## Repo 結構

```
device-trust-playbook/
├── docs/
│   ├── index.html                                          # GitHub Pages 首頁
│   ├── current-device-trust-cra-summary.html              # Device Trust & CRA 整理
│   ├── platform-solution-decision-map.html                # 平台決策圖
│   ├── rot-methods-comparison.html                        # RoT 方法比較
│   ├── cra-annex-mapping.html                             # CRA Annex I 對應
│   ├── planet-analysis.html                               # PLANET 分析
│   ├── meeting-prep-2026-06-12-rot-discussion.html        # 6/12 會議準備
│   ├── techmation-tx8-soteria-optee-ftpm-analysis.html    # TX8 AHB 架構分析
│   └── soteria-native-device-identity-provisioning-survey.html  # NEW: Soteria DevID 調查
├── notes/
│   ├── current-device-trust-cra-summary.md
│   ├── platform-solution-decision-map.md
│   ├── rot-methods-comparison.md
│   ├── techmation-tx8-soteria-optee-ftpm-analysis.md
│   └── soteria-native-device-identity-provisioning-survey.md    # NEW: Soteria DevID 調查
├── references/
│   └── cra/                                               # CRA 參考資料
└── README.md
```

---

## 報告內容

### [`docs/current-device-trust-cra-summary.html`](docs/current-device-trust-cra-summary.html)

**Device Trust & CRA Readiness Current Summary** — 最新整理報告，直接用瀏覽器開啟。包含：

| 章節 | 內容 |
|------|------|
| Executive Summary | 能力核心、CRA 時程、定位說法 |
| Customer / Project Context | PLANET、Techmation TX8、i.MX93 / NXP EL2GO、Mitwell、Legacy MIPS |
| Solution Naming & Positioning | 品牌名稱、正確說法對照表 |
| Platform Solution Decision Table | 10 種平台情境 + Mermaid 決策流程圖 |
| Capability Model | Device Identity → RoT → Provisioning → Firmware Integrity → RA → CRA Evidence |
| CRA Requirement Mapping | CRA Annex I Part I/II 條文對應 |
| PLANET Analysis | 三階段提案、PLANET-side dependencies、MIPS 正確說法 |
| Techmation TX8 Analysis | Soteria hRoT、Phase 1/2 可行性、Phase 3 待確認 |
| Remote Attestation Roadmap | 三階段導入路線、Phase 3 必備條件 |
| What Not to Overclaim | 勿過度承諾對照表 |
| Open Questions | PLANET / TX8 / 內部待確認事項 |
| Source Files Reviewed | 來源文件索引 |
| Gary's PLANET NMS CRA Enforcement Matrix | NMS gap analysis：現有基線 vs 提案強化 vs 商業效益（4 scenarios） |
| PLANET 三階段技術提案時程（GG2 EF1） | Phase 1 (10w) / Phase 2 (9w) / Phase 3 (25w) 工程任務、pre-req、out of scope |

### [`docs/soteria-native-device-identity-provisioning-survey.html`](docs/soteria-native-device-identity-provisioning-survey.html)

**Soteria-native Device Identity & Provisioning Survey** — TX8 研究方向更新（John 2026-06-12）。包含：

| 章節 | 內容 |
|------|------|
| John 方向更新 | 研究軸心：Soteria-native DevID vs OP-TEE fTPM |
| Executive Summary | 能力評估結果（7 已確認 / 13 TBC / 7 可能不支援） |
| Soteria-native 架構 | 製造→部署→運行 DevID 生命週期；Mermaid 架構圖 |
| API 能力調查表 | 27 項 DevID 所需能力 vs Soteria 已知 AHB API（詳細狀態標記） |
| OP-TEE fTPM 分析 | 記憶體佔用、TX8 前提條件、DevID 能力對照 |
| 直接比較表 | Soteria-native vs OP-TEE fTPM 10 維度比較 |
| Device Trust Abstraction Layer | Backend-agnostic 設計；dt_generate_key / dt_sign / dt_store_cert |
| 建議方向 | 短中長期（Q3 2026 → 2027+）工程路線 |
| 問題清單 | 20 個給 John / Techmation / Soteria 的確認問題（A-F 分組） |
| CRA-ready 解讀 | 兩路線的 CRA Annex I 支援程度；定位聲明規則 |
| Action Items | P0/P1/P2/P3 優先級的下一步行動 |

### [`notes/current-device-trust-cra-summary.md`](notes/current-device-trust-cra-summary.md)

同上內容的 Markdown 版本，方便 Git diff / PR review / 長期維護。

---

## 本機開啟

```bash
# 直接用瀏覽器開啟報告
open docs/current-device-trust-cra-summary.html

# 或啟動本機 HTTP server
python3 -m http.server 8080
# 開啟 http://localhost:8080/docs/
```

---

## GitHub Pages 部署

推送版本 tag 時自動部署：

```bash
git tag v0.2.0
git push origin v0.2.0
```

CI workflow（`.github/workflows/`）會：
1. 將所有 `docs/*.html` 中的 `__VERSION__` 替換為 tag 名稱（如 `v0.2.0`）
2. 上傳 `docs/` 並部署到 GitHub Pages

> 本機瀏覽時，version badge 顯示 `dev (local)`；部署後顯示實際 tag（如 `v0.2.0`）。

---

## 來源資料

本 playbook 整理自：

- `../cra-compliance-readiness/` — PLANET CRA / Remote Attestation 分析 repo
  - EU CRA 2024/2847 Annex I 完整條文分析
  - PLANET Gateway 三階段 RA 提案（plan/01）
  - CRA × TTPS / RA solution mapping（analysis/07）
  - Platform Decision Tree（含 Eddie 補充觀點）
  - No-TPM solution paths 分析
  - John Zao MIPS CRA PDF 分析與回應
  - NXP EdgeLock 2GO 會議技術準備
- NXP AN14601 Rev 1.1（i.MX93 CRA Guide，2025-06-25）
- EU CRA 2024/2847 官方條文（EUR-Lex）
- `references/cra/Most Popular fTPM used in IoT or embedded devices (gSrchAI 26-06-10).pdf` — IoT / embedded 設備 fTPM 市場調查（2026-06-10）
- `references/cra/Most Popular vTPM used in IoT or embedded devices (gSrchAI 26-06-10).pdf` — IoT / embedded 設備 vTPM 市場調查（2026-06-10）

---

## 語氣規則

文件中請遵守：

| ✗ 避免 | ✓ 使用 |
|--------|--------|
| guarantee full CRA compliance | CRA-ready · CRA compliance support |
| fully satisfies CRA | supports CRA-related evidence preparation |
| CRA certified | platform-dependent capability |
| TPM equals CRA compliance | hardware-protected key mechanism |
| Remote Attestation immediately available | Remote Attestation is a roadmap |

> Conformity assessment 與 CE marking 的法律責任在 OEM 製造商，FiduciaEdge 提供技術服務。

---

**維護單位：** FiduciaEdge TTPS 團隊
**文件狀態：** 內部討論用，非對外合規聲明
