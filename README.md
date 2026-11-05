<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="markdownToPdf icon">
</p>

<h1 align="center">markdownToPdf</h1>

<p align="center">
  A tiny native macOS app: drop Markdown files in, get clean PDFs out.
  <br>
  <a href="#installation">Install</a> ·
  <a href="#usage">Usage</a> ·
  <a href="#building-from-source">Build from source</a> ·
  <a href="#türkçe">Türkçe</a>
</p>

---

## Features

- **Two tabs:** **Convert** (the default) turns files into PDFs; **Preview** is a Markdown editor with the live PDF beside it. Read a document, edit it and watch the PDF update, and save it only if you click **Save as PDF**.
- **Drag & drop** one or many `.md` files onto the window, or text dragged from another app.
- **Paste from the clipboard:** copy Markdown text from anywhere (a chat, a note, an editor), press **⌘V** in the window and get a PDF named after its first heading.
- **Finder right-click › Convert to PDF** on Markdown files, and **Convert Markdown to PDF** on text selected in any app (macOS Services).
- **Choose where PDFs go:** ask every time, save next to the Markdown file, or always save into one folder. The last two never show a dialog.
- **Asks once per drop:** drop ten files and you pick one folder, once.
- **Merge into one PDF:** files dropped together become a single PDF, each starting on a new page with its own bookmark.
- **Syntax highlighting** for fenced code blocks: Swift, Python, JavaScript, TypeScript, Go, Rust, Java, Kotlin, C/C++, C#, Ruby, PHP, SQL, Bash, JSON, YAML, HTML, CSS and more.
- **History:** the list of saved PDFs is kept between launches. Right-click an item for **Open**, **Show in Finder** or **Remove from List**.
- **Update notice:** when a new version is released on GitHub, a bar at the top of the window tells you.
- **Loading screen** with the file name and "File 2 of 5" progress while converting.
- **GitHub-style output** on A4 pages: headings, tables, task lists, code blocks, block quotes, strikethrough and images (relative paths work).
- **Turkish and English** interface, chosen from your system language.
- Converting works offline; nothing you convert leaves your Mac. The only network request is a once-a-day version check against GitHub.
- Universal app: Apple silicon and Intel, macOS 13 Ventura or later.

<p align="center">
  <img src="docs/sample-page.png" width="420" alt="First page of the PDF made from Examples/sample.md">
  <br>
  <sub>Page 1 of the PDF made from <a href="Examples/sample.md">Examples/sample.md</a></sub>
</p>

## Installation

### Option 1: one command

Open **Terminal** and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/firatkill/markdownToPdf/main/install.sh | bash
```

This downloads the latest release, puts `markdownToPdf.app` in `/Applications` and opens it.

### Option 2: download by hand

1. Go to [Releases](https://github.com/firatkill/markdownToPdf/releases/latest) and download `markdownToPdf-x.y.z.zip`.
2. Double-click the zip and drag **markdownToPdf.app** into **Applications**.
3. The app is not notarized by Apple, so the first time macOS will refuse to open it. Either:
   - open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**, or
   - run this once in Terminal:

     ```bash
     xattr -dr com.apple.quarantine /Applications/markdownToPdf.app
     ```

### Option 3: build it yourself

See [Building from source](#building-from-source).

## Usage

1. Open **markdownToPdf**.
2. Drag one or more Markdown files (`.md`, `.markdown`, `.txt`) onto the window, click **Choose Files…** (⌘O), or press **⌘V** to convert Markdown text you copied.
3. While a file converts you see the loading screen.
4. The PDF is saved according to the **Save** menu at the bottom of the window:

| Save setting | One file | Several files dropped together |
|---|---|---|
| **Ask every time** (default) | A save dialog opens, named after the file (`notes.md` → `notes.pdf`). | You are asked once for a folder; every PDF goes there. |
| **Next to the Markdown file** | Saved beside the `.md` file, no dialog. | Each PDF beside its own `.md` file. |
| **In "folder"** (pick with **Choose Folder…**) | Saved into that folder, no dialog. | All PDFs into that folder. |

When no dialog is shown, nothing is overwritten: if `notes.pdf` already exists, the new file is `notes 2.pdf`. Pasted text has no file to sit next to, so with **Next to the Markdown file** you are asked where to save it. **Cancel** in a dialog skips the file (or the whole drop).

Tick **Merge into one PDF** to turn files dropped together into a single PDF named `Merged.pdf`, in the order they were dropped. Each file starts on a new page and gets a bookmark in Preview's sidebar.

### Preview tab

Click **Preview** at the top right (or press ⌘2). It opens with an empty Markdown editor:

- **Type, paste (⌘V) or drop** a `.md` file into it. Dropping or pasting a file loads its contents; the file itself is never changed.
- As soon as there is text, the **PDF appears on the right** and follows every edit about half a second after you stop typing, keeping your place in the document.
- The **expand** button at the top right of the PDF widens it over the editor for reading; click it again to bring the editor back.
- **Save as PDF** (⌘S) next to it asks where to save. Nothing is written to disk before that, and saved PDFs also appear in the Convert tab's history.
- The PDF view scrolls, zooms (pinch or ⌘+ / ⌘−) and lets you select and copy text. The trash button clears the editor.

### Finder and other apps

- Right-click Markdown files in Finder › **Quick Actions** (or **Services**) › **Convert to PDF**.
- Select Markdown text in any app › right-click › **Services** › **Convert Markdown to PDF**.
- Or right-click a Markdown file › **Open With** › **markdownToPdf**.

If the Services items don't show up, open the app once from `/Applications`, then check **System Settings › Keyboard › Keyboard Shortcuts › Services**.

### History

Saved PDFs stay in the list after you quit. Each row shows when it was saved; click **Saved** to reveal the PDF in Finder, or right-click for **Open**, **Show in Finder** and **Remove from List**. **Clear Finished** empties the list. PDFs that were moved or deleted show **File not found**. Only names and paths are kept, in `~/Library/Application Support/markdownToPdf/history.json`.

### Updates

The app checks GitHub for a new release at most once a day. When there is one, a bar at the top of the window offers **Download** (or **×** to skip that version). **markdownToPdf › Check for Updates…** checks right away. To update, run the install command again or download the new zip.

### Command line

The app binary can also work without opening a window, which is handy in scripts:

```bash
/Applications/markdownToPdf.app/Contents/MacOS/markdownToPdf --convert notes.md notes.pdf
```

```bash
/Applications/markdownToPdf.app/Contents/MacOS/markdownToPdf --merge all.pdf intro.md part1.md part2.md
```

```bash
/Applications/markdownToPdf.app/Contents/MacOS/markdownToPdf --check-for-updates
```

## Building from source

Requirements: macOS 13 or later and Swift 6.2 or later (Xcode 26, or the Command Line Tools: `xcode-select --install`).

```bash
git clone https://github.com/firatkill/markdownToPdf.git
cd markdownToPdf
scripts/build-app.sh
```

The app is written to `build/markdownToPdf.app` and a release zip to `dist/`. Copy the app into `/Applications`:

```bash
cp -R build/markdownToPdf.app /Applications/
```

Use `scripts/build-app.sh --native` to build only for your Mac's chip, which is about twice as fast.

For development, `swift run` starts the app straight from the package.

## How it works

| Step | What happens | Where |
|------|--------------|-------|
| Parse | Markdown is parsed with Apple's [swift-markdown](https://github.com/swiftlang/swift-markdown) (cmark-gfm, so GitHub Flavored Markdown) and turned into HTML. | [`MarkdownHTML.swift`](Sources/MarkdownToPdf/Rendering/MarkdownHTML.swift) |
| Style | The HTML gets a GitHub-like stylesheet tuned for paper; [highlight.js](https://highlightjs.org) (bundled, BSD-3-Clause) colours code blocks. | same file, [`Resources/Web`](Resources/Web) |
| Print | A hidden `WKWebView` loads the page and WebKit's print engine writes a paginated A4 PDF. | [`PDFRenderer.swift`](Sources/MarkdownToPdf/Rendering/PDFRenderer.swift) |
| Merge | PDFKit joins the parts and adds a bookmark per file. | [`PDFMerger.swift`](Sources/MarkdownToPdf/Rendering/PDFMerger.swift) |
| Queue | Files and pasted text are processed strictly one by one: convert → decide where to save → save → record in history. | [`ConversionQueue.swift`](Sources/MarkdownToPdf/Queue/ConversionQueue.swift) |
| Services | Finder's "Convert to PDF" and the text service are declared in `Info.plist` and handled by the app delegate. | [`MarkdownToPdfApp.swift`](Sources/MarkdownToPdf/App/MarkdownToPdfApp.swift) |
| UI | One SwiftUI window with two tabs: Convert (drop zone, file list, loading overlay) and Preview (Markdown editor and live PDFKit viewer). | [`RootView.swift`](Sources/MarkdownToPdf/Views/RootView.swift), [`PreviewView.swift`](Sources/MarkdownToPdf/Preview/PreviewView.swift) |

```
Sources/MarkdownToPdf/
├── App/          app entry point, services, ⌘V, command-line mode
├── Preview/      the Preview tab: editor, live PDF, saving
├── Queue/        conversion queue, jobs, history
├── Rendering/    Markdown → HTML → PDF, merging
├── Support/      settings, update check, English/Turkish strings
└── Views/        the window, Convert tab, drag & drop
Resources/        Info.plist template, app icon, highlight.js, Services menu titles
scripts/          build-app.sh, make-icon.swift
```

## Releasing

Push a version tag and GitHub Actions builds the universal app and publishes the release:

```bash
git tag v1.2.0
git push origin v1.2.0
```

The version number in the app comes from the tag (`v1.2.3` → `1.2.3`); local builds use the [`VERSION`](VERSION) file.

## License

[MIT](LICENSE) © Fırat Kıl

---

## Türkçe

**markdownToPdf**, Markdown dosyalarını PDF'e çeviren küçük, yerel bir macOS uygulamasıdır.

### Özellikler

- **İki sekme:** **Dönüştür** (varsayılan) dosyaları PDF'e çevirir; **Önizle** solda bir Markdown editörü, sağda canlı PDF'tir. Belgeyi okursunuz, düzenledikçe PDF güncellenir; yalnızca **PDF olarak kaydet**'e tıklarsanız kaydedilir.
- Bir ya da birden çok `.md` dosyasını ya da başka bir uygulamadan sürüklediğiniz metni pencereye **sürükleyip bırakın**.
- **Panodan yapıştırın:** herhangi bir yerden kopyaladığınız Markdown metnini pencerede **⌘V** ile yapıştırın; ilk başlığın adıyla PDF olur.
- **Finder'da sağ tık › PDF'e Çevir** (Markdown dosyaları için) ve herhangi bir uygulamada seçili metin için **Markdown'ı PDF'e Çevir**.
- **Kaydetme tercihi:** her seferinde sor, Markdown dosyasının yanına kaydet ya da hep aynı klasöre kaydet. Son ikisinde hiç pencere açılmaz.
- **Her bırakışta bir kez sorar:** on dosya bırakırsanız bir kez klasör seçersiniz.
- **Tek PDF'te birleştir:** birlikte bırakılan dosyalar tek PDF olur; her dosya yeni sayfadan başlar ve kendi yer imini alır.
- Kod bloklarında dile göre **renklendirme**: Swift, Python, JavaScript, TypeScript, Go, Rust, Java, Kotlin, C/C++, C#, Ruby, PHP, SQL, Bash, JSON, YAML, HTML, CSS ve dahası.
- **Geçmiş:** kaydedilen PDF'lerin listesi uygulama kapansa da kalır. Sağ tıkla **Aç**, **Finder'da Göster** ya da **Listeden Kaldır**.
- **Güncelleme bildirimi:** GitHub'da yeni sürüm çıkınca pencerenin üstünde haber verir.
- Dönüştürme sırasında dosya adı ve "5 dosyadan 2. dosya" ilerlemesini gösteren bir **yükleme ekranı** çıkar.
- A4 sayfalarda GitHub tarzı çıktı: başlıklar, tablolar, görev listeleri, kod blokları, alıntılar ve görseller (göreli yollar çalışır).
- Arayüz sistem diline göre Türkçe ya da İngilizce açılır.
- Dönüştürme internetsiz çalışır; dönüştürdüğünüz hiçbir şey bilgisayarınızdan çıkmaz. Tek ağ isteği, günde en fazla bir kez GitHub'dan yapılan sürüm kontrolüdür.

### Kurulum

Terminal'i açıp şunu yapıştırın:

```bash
curl -fsSL https://raw.githubusercontent.com/firatkill/markdownToPdf/main/install.sh | bash
```

Ya da [Releases](https://github.com/firatkill/markdownToPdf/releases/latest) sayfasından zip dosyasını indirip `markdownToPdf.app`'i **Uygulamalar** klasörüne sürükleyin. Uygulama Apple tarafından onaylanmadığı (notarize edilmediği) için ilk açılışta macOS izin vermeyebilir. Bu durumda **Sistem Ayarları → Gizlilik ve Güvenlik** bölümünde **Yine de Aç**'a tıklayın ya da Terminal'de bir kez şunu çalıştırın:

```bash
xattr -dr com.apple.quarantine /Applications/markdownToPdf.app
```

### Kullanım

1. **markdownToPdf**'i açın.
2. Markdown dosyalarını pencereye bırakın, **Dosya Seç…** düğmesine tıklayın (⌘O) ya da kopyaladığınız Markdown metnini **⌘V** ile yapıştırın.
3. Dönüştürme sırasında yükleme ekranı görünür.
4. PDF, pencerenin altındaki **Kaydet** menüsüne göre kaydedilir:

| Kaydetme tercihi | Tek dosya | Birlikte bırakılan dosyalar |
|---|---|---|
| **Her seferinde sor** (varsayılan) | Dosyanın adıyla (`notlar.md` → `notlar.pdf`) kaydetme penceresi açılır. | Bir kez klasör sorulur, tüm PDF'ler oraya. |
| **Markdown dosyasının yanına** | `.md` dosyasının yanına, pencere açılmadan. | Her PDF kendi `.md` dosyasının yanına. |
| **"klasör" klasörüne** (**Klasör Seç…** ile) | O klasöre, pencere açılmadan. | Tüm PDF'ler o klasöre. |

Pencere açılmadığında hiçbir dosyanın üzerine yazılmaz: `notlar.pdf` zaten varsa yenisi `notlar 2.pdf` olur. Yapıştırılan metnin yanına konacağı bir dosya olmadığı için **Markdown dosyasının yanına** seçiliyken nereye kaydedileceği sorulur. Pencerede **Vazgeç** dosyayı (ya da o bırakışın tamamını) atlar.

**Tek PDF'te birleştir** işaretliyse birlikte bırakılan dosyalar bırakıldıkları sırayla `Birleştirilmiş.pdf` adlı tek bir PDF olur. Her dosya yeni sayfadan başlar ve Önizleme'nin kenar çubuğunda kendi yer imini alır.

**Önizle sekmesi:** sağ üstteki **Önizle**'ye tıklayın (ya da ⌘2). Boş bir Markdown editörü açılır. İçine yazın, **⌘V** ile yapıştırın ya da bir `.md` dosyası bırakın (dosyanın içeriği yüklenir, dosyanın kendisi değişmez). Metin olunca **PDF sağda görünür** ve yazmayı bıraktıktan yaklaşık yarım saniye sonra her değişikliği yansıtır; belgede kaldığınız yer korunur. PDF'in sağ üstündeki **genişlet** düğmesi PDF'i editörün üstüne genişletir, tekrar tıklayınca editör geri gelir. Yanındaki **PDF olarak kaydet** (⌘S) nereye kaydedileceğini sorar; o ana kadar diske hiçbir şey yazılmaz. Önizlemeden kaydedilen PDF'ler Dönüştür sekmesinin geçmişinde de görünür.

**Finder ve diğer uygulamalar:** Finder'da Markdown dosyalarına sağ tıklayıp **Hızlı İşlemler** (ya da **Servisler**) › **PDF'e Çevir**'i seçin. Herhangi bir uygulamada Markdown metnini seçip sağ tık › **Servisler** › **Markdown'ı PDF'e Çevir**. Bu seçenekler görünmüyorsa uygulamayı bir kez `/Applications`'tan açın, sonra **Sistem Ayarları › Klavye › Klavye Kestirmeleri › Servisler** bölümüne bakın.

**Geçmiş:** kaydedilen PDF'ler uygulamadan çıktıktan sonra da listede kalır; her satırda ne zaman kaydedildiği yazar. Sağ tıkla **Aç**, **Finder'da Göster** ve **Listeden Kaldır**. **Bitenleri Temizle** listeyi boşaltır. Taşınan ya da silinen PDF'ler **Dosya bulunamadı** olarak görünür. Yalnızca adlar ve yollar `~/Library/Application Support/markdownToPdf/history.json` dosyasında tutulur.

**Güncellemeler:** uygulama günde en fazla bir kez GitHub'da yeni sürüm olup olmadığına bakar. Varsa pencerenin üstünde **İndir** düğmesiyle bir şerit çıkar (**×** o sürümü atlar). **markdownToPdf › Güncellemeleri Denetle…** hemen kontrol eder. Güncellemek için kurulum komutunu tekrar çalıştırın ya da yeni zip'i indirin.

### Kaynaktan derleme

macOS 13+ ve Swift 6.2+ (Xcode 26 ya da Command Line Tools) gerekir:

```bash
git clone https://github.com/firatkill/markdownToPdf.git
cd markdownToPdf
scripts/build-app.sh
cp -R build/markdownToPdf.app /Applications/
```
