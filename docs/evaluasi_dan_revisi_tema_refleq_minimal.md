# 🎨 Hasil Diskusi 2 Senior Design Lead: Transformasi Tema "Refleq Minimal Aurora"
## Personal Hub v2.5 — Mengakhiri Monotoni Visual dengan Estetika Neo-Pastel Modern

**Partisipan Diskusi Desain:**
1. **Agent 1: Senior Design System & Color Specialist** (Mantan Google Material Design Core Lead)
2. **Agent 2: Principal UX Architect & Ergonomics Specialist** (Android System UI & Productivity Lead)

**Dokumen Referensi Utama:**
- Pinterest Pin Baru: [docs/design_reference/pinterest_ref_04_refleq_minimal.png](file:///D:/Mobile/Scribd/docs/design_reference/pinterest_ref_04_refleq_minimal.png) (`https://id.pinterest.com/pin/1108378158347033409/`)
- Desain Referensi Sebelumnya: [docs/design_reference/README.md](file:///D:/Mobile/Scribd/docs/design_reference/README.md)

---

## 1. Transkrip & Sintesis Diskusi Desain (2 Senior Agents)

### A. Diagnosa: Mengapa Tema Sebelumnya Terasa "Monoton"?
- **Agent 1 (Color Specialist):**
  > *"Tema kita sebelumnya terlalu terjebak dalam gaya 'Cyberpunk Dark' yang monoton: kanvas hitam mati `#0B0F19`, teks abu-abu dingin, dan hanya mengandalkan Neon Lime `#C6F432` serta ungu tunggal `#8B5CF6`. Ketika semua kartu berwarna abu-abu kaca gelap yang identik, hierarki visual menjadi rata dan membosankan. Mata pengguna cepat lelah karena tidak ada dinamisme ritme warna."*

- **Agent 2 (UX Architect):**
  > *"Saya sangat sepakat. Pada referensi Pinterest baru (`Refleq Minimal UI` - `pinterest_ref_04_refleq_minimal.png`), kita melihat bagaimana aplikasi produktivitas modern menggunakan **Color-Blocked Tinted Cards** dan **Sunset Aurora Gradients**. Setiap blok waktu dan kategori memiliki kepribadian visual:
  > - Pink/Rose (`#FB7185`) untuk aktivitas fisik/kesehatan.
  > - Sky Blue (`#38BDF8`) untuk rapat/klien.
  > - Soft Lavender (`#A78BFA` & `#8B5CF6`) untuk tugas kreatif/desain.
  > - Warm Peach/Amber (`#FBBF24`) untuk waktu istirahat dan peringatan.
  > Ini bukan sekadar hiasan kosmetik, melainkan **Visual Chunking** yang memangkas beban kognitif pengguna hingga 50%!"*

### B. Keputusan Desain: Bahasa Desain "Refleq Minimal Aurora"
Keduanya sepakat mengganti tema lama menjadi **Refleq Minimal Aurora (Dark & Luminous Obsidian)**:

1. **Kanvas & Kedalaman Latar (Atmospheric Obsidian):**
   - Bukan hitam pekat mati, melainkan **Deep Obsidian Indigo** (`#0C101D` dan `#0F1424`).
   - Lapisan gradien halus yang memberikan kedalaman ruang (*spatial ambient depth*).

2. **Sistem Kartu "Color-Stripe Pastels" (Identik Pin Refleq):**
   - Setiap kartu memiliki garis aksen vertikal di tepi kiri (lebar 4dp, radius 2dp) dengan warna aksen pastel yang serasi.
   - Badan kartu menggunakan *Frosted Tinted Glass* (`rgba(255, 255, 255, 0.05)` hingga `0.08`) dengan border specular atas yang tipis dan elegan.
   - Badge waktu menggunakan kapsul pastel lembut dengan teks kontras tinggi (misal pil `#FFF1F2` dengan teks `#E11D48` atau `#FB7185`).

3. **Bottom Navigation Capsule Dock:**
   - Bentuk kapsul melayang penuh (`BorderRadius.circular(36)`).
   - Tombol aktif menggunakan **Sunset Aurora Gradient Pill** (`#8B5CF6` ungu violet bertransisi ke `#F43F5E` / `#FB7185` sunset rose) yang menyala lembut.
   - Tombol aksi cepat "+" sirkular terintegrasi di sisi dock.

4. **Weekly / Prayer Date Strip Capsule:**
   - Kapsul hari vertikal (Huruf hari di atas, angka tanggal di bawah).
   - Kapsul tanggal yang aktif dilingkari border gradien aurora (*sunset ring*) atau diisi background lavender luminous.

5. **Aksen Interaktif & Progress Bar:**
   - Progress bar (Zakat nisab, cashflow burn rate, habit tracker) menggunakan **Sunset Glow Gradient** (`#FB7185` -> `#FBBF24` atau `#8B5CF6` -> `#38BDF8`).

---

## 2. Definisi Desain Token Baru ("Refleq Aurora")

### A. Palet Warna Global (`AppColors` / `RefleqPalette`)
```dart
class RefleqPalette {
  // Kanvas & Permukaan Obsidian
  static const Color background = Color(0xFF0C101D);       // Deep Obsidian Indigo
  static const Color surface = Color(0xFF13192B);          // Elevated Obsidian Slate
  static const Color surfaceCard = Color(0xFF182035);      // Frosted Card Slate
  static const Color surfaceBorder = Color(0x1FFFFFFF);    // 12% Specular White

  // Refleq Aurora Pastel Accents (Sesuai pinterest_ref_04)
  static const Color rosePink = Color(0xFFFB7185);         // Aktivitas Kesehatan / Prioritas
  static const Color rosePinkSurface = Color(0x22FB7185);   // Tinted Chip Background
  static const Color skyCyan = Color(0xFF38BDF8);          // Meeting / Client Schedule
  static const Color skyCyanSurface = Color(0x2238BDF8);    // Tinted Chip Background
  static const Color lavender = Color(0xFFA78BFA);         // Notes / AI / Creative
  static const Color lavenderSurface = Color(0x22A78BFA);  // Tinted Chip Background
  static const Color amberPeach = Color(0xFFFBBF24);       // Break / Warning / Zakat Due
  static const Color amberPeachSurface = Color(0x22FBBF24);// Tinted Chip Background
  static const Color emeraldMint = Color(0xFF34D399);      // Finance Income / Positive
  static const Color emeraldMintSurface = Color(0x2234D399);

  // Sunset Aurora Gradient
  static const LinearGradient sunsetAurora = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFF43F5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetWarm = LinearGradient(
    colors: [Color(0xFFFB7185), Color(0xFFFBBF24)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient lavenderCloud = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
```

---

## 3. Rencana Pembagian Tugas 5 Agent Pararel

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        DELEGASI 5 AGENT PARAREL (REFLEQ THEME)                         │
├─────────┬──────────────────────────────────┬───────────────────────────────────────────┤
│ Agent   │ Domain / Modul                   │ File Target & Tanggung Jawab              │
├─────────┼──────────────────────────────────┼───────────────────────────────────────────┤
│ Agent 1 │ Theme Core & Glass Widgets       │ lib/core/theme/app_theme.dart             │
│         │                                  │ lib/core/theme/glass_widgets.dart         │
│         │                                  │ - RefleqPalette, Sunset Aurora Gradient   │
│         │                                  │ - RefleqColorStripeCard, Nav Capsule Dock │
├─────────┼──────────────────────────────────┼───────────────────────────────────────────┤
│ Agent 2 │ Beranda (Home Dashboard)         │ lib/features/home/ui/home_screen.dart     │
│         │                                  │ - Refleq Hero Card, Date capsule strip    │
│         │                                  │ - 2x2 Action Tiles tinted pastel          │
│         │                                  │ - Reactive AI Copilot badge aurora        │
├─────────┼──────────────────────────────────┼───────────────────────────────────────────┤
│ Agent 3 │ Meetings (Jadwal & Agenda)       │ lib/features/meetings/ui/meetings_screen. │
│         │                                  │ - Match pinterest_ref_04 timeline:        │
│         │                                  │   left time stamp, color-stripe cards,    │
│         │                                  │   amber break banner, capsule date bar    │
├─────────┼──────────────────────────────────┼───────────────────────────────────────────┤
│ Agent 4 │ Finance & Zakat Mal              │ lib/features/finance/ui/finance_screen.   │
│         │                                  │ - Sunset gradient burn rate & zakat bar   │
│         │                                  │ - Pastel tinted expense categories        │
│         │                                  │ - Refleq segmented tab pills              │
├─────────┼──────────────────────────────────┼───────────────────────────────────────────┤
│ Agent 5 │ Notes & Vault/Settings           │ lib/features/notes/ui/notes_screen.dart   │
│         │                                  │ lib/features/notes/ui/note_editor_screen. │
│         │                                  │ lib/features/vault/ui/vault_gate_screen.  │
│         │                                  │ - Squircle "Create New Note" lavender     │
│         │                                  │ - Pinpad Refleq obsidian glass            │
└─────────┴──────────────────────────────────┴───────────────────────────────────────────┘
```
