# 🎨 Panduan & Katalog Desain UI/UX Personal Hub v2.0

Dokumen ini mendokumentasikan sistem desain **Neo-Modern Dark Glassmorphism** yang diterapkan pada Personal Hub. Sistem ini dirancang berdasarkan inspirasi visual dari Pinterest pins dan telah diimplementasikan 100% ke dalam aplikasi Flutter.

---

## 📸 1. Bukti Visual Hasil Implementasi (Screenshots Aplikasi Nyata)

| Berkas Screenshot | Layar | Elemen Desain yang Terpasang |
| :--- | :--- | :--- |
| [01_beranda_dashboard.png](file:///D:/Mobile/Scribd/docs/design_reference/01_beranda_dashboard.png) | **Beranda (Dashboard)** | Header dinamis neo-modern, Pill status "Copilot Aktif", Hero Card Sholat dengan Curved Arc Progress & rapat terdekat, 2x2 Modular Action Tiles, Floating Quick-Capture Bar, dan Floating Dark Capsule Navigation Bar. |
| [02_catatan_screen.png](file:///D:/Mobile/Scribd/docs/design_reference/02_catatan_screen.png) | **Catatan & Ide** | Glassmorphism cards dengan border teal pada catatan disematkan, horizontal tag filter chips (`#ide`, `#kerja`, `#pribadi`), tombol unduh Markdown `.md` dengan YAML frontmatter. |
| [03_meeting_screen.png](file:///D:/Mobile/Scribd/docs/design_reference/03_meeting_screen.png) | **Agenda Rapat** | Horizontal Date Picker Strip (Senin-Minggu) dengan pil ungu aktif menyala (`#8B5CF6`), Schedule Guardian warning banner (tabrakan sholat), kartu rapat berkategori warna (review, tim, client), avatar peserta bertumpuk, tombol 1-tap iCal export. |
| [04_vault_gate_screen.png](file:///D:/Mobile/Scribd/docs/design_reference/04_vault_gate_screen.png) | **Brankas Sandi (Vault)** | Glass Gate dengan badge AES-256-GCM Zero-Knowledge, keypad PIN responsif, proteksi Duress PIN (Decoy Mode), dan konfigurasi Auto-Lock Timeout. |
| [05_ai_chat_screen.png](file:///D:/Mobile/Scribd/docs/design_reference/05_ai_chat_screen.png) | **AI Copilot** | Antarmuka chat AI dengan Hybrid 3-tier routing (Heuristik, Local SLM offline, Samudra Cloud), bubble chat transparan, dan quick action pills. |

---

## 📌 2. Sumber Inspirasi Desain Pinterest

| Berkas Referensi | Sumber | Fitur yang Diadopsi |
| :--- | :--- | :--- |
| [pinterest_ref_01_app_store_onboarding.jpg](file:///D:/Mobile/Scribd/docs/design_reference/pinterest_ref_01_app_store_onboarding.jpg) | **Pinterest Pin 1** | Bold Display Typography (800 weight), blok kartu kontras tinggi Neon Lime (`#C6F432`) & Pastel Coral (`#FFAA9B`), badge pill status. |
| [pinterest_ref_02_quickly_find_ui.jpg](file:///D:/Mobile/Scribd/docs/design_reference/pinterest_ref_02_quickly_find_ui.jpg) | **Pinterest Pin 2** | Circular Progress Ring ganda, 2x2 Modular Action Tiles (Radius 24px) dengan tombol panah aksi, grafik tren, Floating Capsule Nav Bar. |
| [pinterest_ref_03_project_management_ui.jpg](file:///D:/Mobile/Scribd/docs/design_reference/pinterest_ref_03_project_management_ui.jpg) | **Pinterest Pin 3** | Hero Task Card ungu gradasi (`#8B5CF6`), Horizontal Date Strip dengan pil ungu aktif, timeline rapat dengan tag warna & avatar peserta bertumpuk. |
| [pinterest_ref_04_refleq_minimal.png](file:///D:/Mobile/Scribd/docs/design_reference/pinterest_ref_04_refleq_minimal.png) | **Pinterest Pin 4 (Refleq Minimal)** | **Desain Utama**: Color-Stripe Pastels (Rose `#FB7185`, Sky `#38BDF8`, Lavender `#A78BFA`), Sunset Aurora Gradient Dock, Date Capsule Pills dengan ring aktif, time badges, dan Squircle action cards. |

---

## 🛠️ 3. Token Desain Resmi Refleq Minimal Aurora

```json
{
  "borderRadius": {
    "heroCard": "24px",
    "actionTile": "18px",
    "colorStripeCard": "20px",
    "chipPill": "100px",
    "bottomNav": "36px"
  },
  "palette": {
    "canvasObsidian": "#0C101D",
    "surfaceSlate": "#13192B",
    "surfaceGlass": "rgba(24, 32, 53, 0.72)",
    "glassBorder": "rgba(255, 255, 255, 0.10)",
    "accentRosePink": "#FB7185",
    "accentSkyCyan": "#38BDF8",
    "accentLavender": "#A78BFA",
    "accentRoyalViolet": "#8B5CF6",
    "accentAmberPeach": "#FBBF24",
    "accentEmeraldMint": "#34D399"
  },
  "gradients": {
    "sunsetAurora": "linear-gradient(135deg, #8B5CF6 0%, #F43F5E 100%)",
    "sunsetWarm": "linear-gradient(90deg, #FB7185 0%, #FBBF24 100%)",
    "lavenderCloud": "linear-gradient(135deg, #8B5CF6 0%, #A78BFA 100%)"
  },
  "typography": {
    "fontFamily": "Plus Jakarta Sans",
    "displayHeadingWeight": 800,
    "titleWeight": 700,
    "bodyWeight": 400
  }
}
```
