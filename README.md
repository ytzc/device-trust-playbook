# Device Trust & Platform Security Playbook

設備信任、Root of Trust、安全佈建、設備上線、韌體完整性、Remote Attestation，以及 CRA-ready 產品安全的技術作戰手冊。

---

## 用途

本 repo 是 FiduciaEdge 的長期技術知識庫，涵蓋：

- **Device Identity** — IDevID / LDevID，hardware-bound，non-exportable private key
- **Root of Trust** — TPM 2.0 / fTPM / hTPM / Soteria hRoT / External SE / PUF
- **Secure Provisioning & Onboarding** — TTPS DI、FDO（FIDO Device Onboard）、zero-touch provisioning
- **Firmware Integrity** — Secure Boot、Measured Boot、SBOM
- **Remote Attestation** — Measured Boot evidence、signed report、NMS policy engine
- **CRA Readiness** — EU CRA 2024/2847 Annex I 技術控制對應、evidence preparation、conformity assessment support

> **CRA 全面強制執行日：2027-12-11**

---

## Repo 結構

```
device-trust-playbook/
├── docs/
│   ├── index.html                           # GitHub Pages 首頁（由 CI 部署）
│   └── current-device-trust-cra-summary.html  # Device Trust & CRA 整理報告
├── notes/
│   └── current-device-trust-cra-summary.md    # 知識筆記（Markdown 版）
├── references/
│   └── cra/                                 # CRA 參考資料
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
| Platform Solution Decision Table | 10 種平台情境（x86、ARM fTPM、TX8、External SE、Legacy MIPS、RISC-V、VM…） |
| Capability Model | Device Identity → RoT → Provisioning → Firmware Integrity → RA → CRA Evidence |
| CRA Requirement Mapping | CRA Annex I Part I/II 條文對應 |
| PLANET Analysis | 三階段提案、PLANET-side dependencies、MIPS 正確說法 |
| Techmation TX8 Analysis | Soteria hRoT、Phase 1/2 可行性、Phase 3 待確認 |
| Remote Attestation Roadmap | 三階段導入路線、Phase 3 必備條件 |
| What Not to Overclaim | 勿過度承諾對照表 |
| Open Questions | PLANET / TX8 / 內部待確認事項 |
| Source Files Reviewed | 來源文件索引 |

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
