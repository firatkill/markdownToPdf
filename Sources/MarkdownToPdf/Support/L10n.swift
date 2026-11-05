import Foundation

/// User-facing strings in English and Turkish. The language follows the system setting.
enum L10n {
    static let isTurkish = Locale.preferredLanguages.first?.hasPrefix("tr") ?? false

    private static func t(_ english: String, _ turkish: String) -> String {
        isTurkish ? turkish : english
    }

    static let dropTitle = t("Drop Markdown files here", "Markdown dosyalarını buraya bırakın")
    static let dropSubtitle = t(
        "One or many .md files, or paste Markdown text with ⌘V.",
        "Bir ya da birden çok .md dosyası; ya da Markdown metnini ⌘V ile yapıştırın."
    )
    static let chooseFiles = t("Choose Files…", "Dosya Seç…")
    static let pasteFromClipboard = t("Paste from Clipboard", "Panodan Yapıştır")
    static let pastedTextName = t("Pasted text", "Yapıştırılan metin")
    static let pastedBadge = t("from clipboard", "panodan")
    static let clipboardEmpty = t(
        "The clipboard has no text or Markdown files.",
        "Panoda metin ya da Markdown dosyası yok."
    )
    static let queueTitle = t("Files", "Dosyalar")
    static let clearFinished = t("Clear Finished", "Bitenleri Temizle")

    static let statusWaiting = t("Waiting", "Sırada")
    static let statusConverting = t("Converting…", "Dönüştürülüyor…")
    static let statusAwaitingSave = t("Choose where to save", "Kaydetme yeri bekleniyor")
    static let statusSaved = t("Saved", "Kaydedildi")
    static let statusSkipped = t("Not saved", "Kaydedilmedi")
    static let statusFailed = t("Failed", "Başarısız")
    static let statusConverted = t("Ready to merge", "Birleştirilmeyi bekliyor")
    static let mergeIntoOne = t("Merge into one PDF", "Tek PDF'te birleştir")
    static let mergeHelp = t(
        "Files dropped together become one PDF, each starting on a new page.",
        "Birlikte bırakılan dosyalar tek PDF olur; her dosya yeni sayfadan başlar."
    )
    static let mergedFileName = t("Merged", "Birleştirilmiş")
    static let loadingSavingMerged = t("Choose where to save the merged PDF", "Birleştirilmiş PDF'in kaydedileceği yeri seçin")
    static let errorMerge = t("The PDFs could not be merged.", "PDF'ler birleştirilemedi.")

    static let menuOpen = t("Open", "Aç")
    static let menuShowInFinder = t("Show in Finder", "Finder'da Göster")

    static let loadingConverting = t("Converting to PDF", "PDF'e dönüştürülüyor")
    static let loadingSaving = t("Choose where to save the PDF", "PDF'in kaydedileceği yeri seçin")
    static let loadingChooseFolder = t("Choose a folder for all PDFs", "Tüm PDF'ler için bir klasör seçin")

    static func progress(_ current: Int, _ total: Int) -> String {
        t("File \(current) of \(total)", "\(total) dosyadan \(current). dosya")
    }

    static let savePanelTitle = t("Save PDF", "PDF'i Kaydet")
    static let savePanelButton = t("Save", "Kaydet")
    static let folderPanelTitle = t("Save PDFs", "PDF'leri Kaydet")

    static func folderPanelMessage(_ count: Int) -> String {
        t("Choose one folder for all \(count) PDFs", "\(count) PDF'in tamamı için bir klasör seçin")
    }
    static let saveLabel = t("Save:", "Kaydet:")
    static let saveModeAsk = t("Ask every time", "Her seferinde sor")
    static let saveModeNextToSource = t("Next to the Markdown file", "Markdown dosyasının yanına")
    static func saveModeFolder(_ name: String) -> String { t("In “\(name)”", "“\(name)” klasörüne") }
    static let chooseSaveFolder = t("Choose Folder…", "Klasör Seç…")
    static let chooseSaveFolderMessage = t(
        "PDFs will be saved here without asking",
        "PDF'ler sormadan buraya kaydedilecek"
    )
    static let chooseButton = t("Choose", "Seç")
    static let saveFolderMissing = t(
        "The save folder no longer exists, so you are asked instead.",
        "Kaydetme klasörü artık yok, bu yüzden nereye kaydedileceği soruluyor."
    )
    static let openPanelMessage = t("Choose Markdown files to convert", "Dönüştürülecek Markdown dosyalarını seçin")
    static let unsupportedFiles = t(
        "Only Markdown files (.md, .markdown, .txt) can be converted.",
        "Yalnızca Markdown dosyaları (.md, .markdown, .txt) dönüştürülebilir."
    )

    static let errorUnreadable = t("The file could not be read.", "Dosya okunamadı.")
    static let errorPrint = t("The PDF could not be created.", "PDF oluşturulamadı.")
    static let errorSave = t("The PDF could not be saved there.", "PDF oraya kaydedilemedi.")
}
