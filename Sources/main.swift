import SwiftUI
import Foundation
import CryptoKit
import AppKit

private let packageURL = URL(string: "https://github.com/CostelaCNX/CNX/releases/download/23.0.1-1/CNX.23.0.1-1.zip")!
private let expectedSHA256 = "7e9972b03e837c0d49aeeecb8b80a79d5d1cb0bda9609c8d0ac8147015e6180a"

struct Drive: Identifiable, Hashable {
    let id: String
    let name: String
    let size: String
    let bytes: Int64
    var description: String { "\(name) • \(size) • /dev/\(id)" }
}

enum InstallerError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}

func command(_ path: String, _ args: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let output = String(data: data, encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else {
        throw InstallerError.message("Comando falhou: \(output.prefix(700))")
    }
    return output
}

func diskInfo(_ id: String) throws -> [String: Any] {
    let output = try command("/usr/sbin/diskutil", ["info", "-plist", id])
    guard let bytes = output.data(using: .utf8),
          let plist = try PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any] else {
        throw InstallerError.message("Não foi possível identificar o disco.")
    }
    return plist
}

func bool(_ dict: [String: Any], _ key: String) -> Bool { dict[key] as? Bool ?? false }
func string(_ dict: [String: Any], _ key: String) -> String { dict[key] as? String ?? "" }
func isSafeExternal(_ disk: [String: Any], id: String) -> Bool {
    guard id.range(of: #"^disk[0-9]+$"#, options: .regularExpression) != nil else { return false }
    guard bool(disk, "WholeDisk") && !bool(disk, "Internal") else { return false }
    guard bool(disk, "RemovableMedia") || bool(disk, "Ejectable") else { return false }
    let physical = string(disk, "VirtualOrPhysical")
    if !physical.isEmpty && physical != "Physical" { return false }
    guard (disk["TotalSize"] as? NSNumber)?.int64Value ?? 0 > 512_000_000 else { return false }
    return true
}

func externalDrives() throws -> [Drive] {
    let output = try command("/usr/sbin/diskutil", ["list", "-plist", "external", "physical"])
    guard let bytes = output.data(using: .utf8),
          let obj = try PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any] else { return [] }
    let candidates = obj["AllDisksAndPartitions"] as? [[String: Any]] ?? []
    return candidates.compactMap { item in
        guard let id = item["DeviceIdentifier"] as? String,
              let disk = try? diskInfo(id), isSafeExternal(disk, id: id) else { return nil }
        let size = (disk["TotalSize"] as? NSNumber)?.int64Value ?? 0
        let label = string(disk, "MediaName").isEmpty ? "Cartão / Unidade removível" : string(disk, "MediaName")
        return Drive(id: id, name: label, size: ByteCountFormatter.string(fromByteCount: size, countStyle: .decimal), bytes: size)
    }
}

// Revalidamos logo antes da operação destrutiva, inclusive nome e capacidade.
func validateDrive(_ selected: Drive) throws {
    let info = try diskInfo(selected.id)
    let size = (info["TotalSize"] as? NSNumber)?.int64Value ?? 0
    guard isSafeExternal(info, id: selected.id), size == selected.bytes,
          (string(info, "MediaName").isEmpty ? "Cartão / Unidade removível" : string(info, "MediaName")) == selected.name else {
        throw InstallerError.message("O cartão foi trocado ou não é uma unidade removível segura. Atualize a lista.")
    }
}

func sha256(_ url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hash = SHA256()
    while true {
        let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
        if data.isEmpty { break }
        hash.update(data: data)
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
}

func validatedArchiveEntries(_ zip: URL) throws {
    let list = try command("/usr/bin/unzip", ["-Z", "-1", zip.path])
    let names = list.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    guard !names.isEmpty else { throw InstallerError.message("O arquivo ZIP está vazio.") }
    for name in names {
        let path = name.replacingOccurrences(of: "\\", with: "/")
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        if path.hasPrefix("/") || components.contains("..") || components.contains(".") || path.contains("\u{0000}") || path.contains(":") {
            throw InstallerError.message("O ZIP contém um caminho inseguro: \(name)")
        }
    }
}

func packageRoot(_ extracted: URL) throws -> URL {
    let fm = FileManager.default
    let ignore = ["__MACOSX", ".DS_Store"]
    let contents = try fm.contentsOfDirectory(at: extracted, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        .filter { !ignore.contains($0.lastPathComponent) }
    guard !contents.isEmpty else { throw InstallerError.message("Nenhum arquivo encontrado no pacote.") }
    if contents.count == 1, let only = contents.first,
       (try only.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true { return only }
    return extracted
}

func isValidPayload(_ root: URL) -> Bool {
    let fm = FileManager.default
    return fm.fileExists(atPath: root.appendingPathComponent("atmosphere").path) &&
           (fm.fileExists(atPath: root.appendingPathComponent("bootloader").path) ||
            fm.fileExists(atPath: root.appendingPathComponent("switch").path))
}

// AppleScript só recebe comando e identificador rigidamente verificado (diskN).
func eraseCard(_ id: String) throws {
    guard id.range(of: #"^disk[0-9]+$"#, options: .regularExpression) != nil else {
        throw InstallerError.message("Identificador inválido.")
    }
    let shell = "/usr/sbin/diskutil eraseDisk FAT32 CNX MBRFormat /dev/\(id)"
    let appleScript = "do shell script \"\(shell)\" with administrator privileges"
    _ = try command("/usr/bin/osascript", ["-e", appleScript])
}

func volumePath(_ disk: String) throws -> URL {
    let output = try command("/usr/sbin/diskutil", ["info", "-plist", disk + "s1"])
    guard let data = output.data(using: .utf8),
          let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let path = plist["MountPoint"] as? String,
          path.hasPrefix("/Volumes/") else {
        throw InstallerError.message("O cartão foi formatado, mas não montou. Confira o Utilitário de Disco.")
    }
    return URL(fileURLWithPath: path, isDirectory: true)
}

func copyAndCheck(from root: URL, to destination: URL) throws {
    let fm = FileManager.default
    let contents = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
    for item in contents {
        let target = destination.appendingPathComponent(item.lastPathComponent)
        try fm.copyItem(at: item, to: target)
    }
    guard fm.fileExists(atPath: destination.appendingPathComponent("atmosphere").path) else {
        throw InstallerError.message("Não foi possível verificar os arquivos no cartão.")
    }
    _ = try command("/bin/sync", [])
}

@MainActor final class InstallerModel: ObservableObject {
    @Published var drives: [Drive] = []
    @Published var selected: Drive?
    @Published var busy = false
    @Published var status = "Conecte o cartão SD e clique em Atualizar."
    @Published var progress = 0.0
    @Published var showConfirmation = false
    @Published var showResult = false
    @Published var result = ""

    func refresh() {
        guard !busy else { return }
        do {
            drives = try externalDrives()
            selected = drives.first(where: { $0.id == selected?.id })
            status = drives.isEmpty ? "Nenhum cartão removível compatível encontrado." : "Selecione o cartão SD."
        } catch {
            status = "Erro ao listar discos: \(error.localizedDescription)"
        }
    }
    func update(_ step: String, _ value: Double) { status = step; progress = value }
    func install() {
        guard let selected, !busy else { return }
        busy = true; progress = 0; status = "Baixando pacote..."
        Task.detached { [weak self] in
            let fm = FileManager.default
            let folder = fm.temporaryDirectory.appendingPathComponent("CNXInstaller-" + UUID().uuidString, isDirectory: true)
            do {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                let (download, _) = try await URLSession.shared.download(from: packageURL)
                let archive = folder.appendingPathComponent("CNX.zip")
                try fm.moveItem(at: download, to: archive)
                await self?.update("Verificando SHA-256 e conteúdo...", 0.33)
                guard try sha256(archive) == expectedSHA256 else {
                    throw InstallerError.message("Hash SHA-256 incorreto. O cartão NÃO foi formatado.")
                }
                try validatedArchiveEntries(archive)
                let extraction = folder.appendingPathComponent("extraido", isDirectory: true)
                try fm.createDirectory(at: extraction, withIntermediateDirectories: true)
                _ = try command("/usr/bin/ditto", ["-x", "-k", archive.path, extraction.path])
                let root = try packageRoot(extraction)
                guard isValidPayload(root) else {
                    throw InstallerError.message("Estrutura CNX não reconhecida. O cartão NÃO foi formatado.")
                }
                await self?.update("Revalidando cartão SD...", 0.55)
                try validateDrive(selected)
                await self?.update("Formatando FAT32 (será solicitada a senha do macOS)...", 0.62)
                try eraseCard(selected.id)
                await self?.update("Copiando arquivos para o cartão...", 0.78)
                let target = try volumePath(selected.id)
                try copyAndCheck(from: root, to: target)
                await self?.finish("CNX instalado com sucesso. Ejete o cartão pelo Finder antes de removê-lo.", success: true)
            } catch {
                await self?.finish("Operação interrompida: \(error.localizedDescription)\n\nSe a formatação já começou, o cartão pode estar vazio ou parcialmente preparado.", success: false)
            }
            try? fm.removeItem(at: folder)
        }
    }
    func finish(_ message: String, success: Bool) {
        busy = false; progress = success ? 1 : 0
        status = success ? "Instalação concluída." : "Não concluído."
        result = message; showResult = true
        refresh()
    }
}

@main struct CNXInstallerApp: App {
    @StateObject private var model = InstallerModel()
    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.fill.badge.plus").font(.system(size: 33)).foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CNX Installer").font(.title.bold())
                        Text("Preparador de cartão SD para macOS").foregroundStyle(.secondary)
                    }
                }
                Divider()
                HStack {
                    Text("1. Cartão SD").font(.headline)
                    Spacer()
                    Button("Atualizar") { model.refresh() }.disabled(model.busy)
                }
                Picker("Unidade removível", selection: $model.selected) {
                    Text("Selecione o cartão...").tag(nil as Drive?)
                    ForEach(model.drives) { drive in
                        Text(drive.description).tag(Optional(drive))
                    }
                }.disabled(model.busy)
                Text("Confira o nome, a capacidade e o identificador antes de continuar.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text("2. Pacote CNX").font(.headline)
                HStack {
                    Image(systemName: "shippingbox.fill").foregroundStyle(.blue)
                    Text("CNX 23.0.1-1 — download oficial do GitHub")
                }
                Text("O pacote será baixado, verificado e extraído antes de qualquer formatação.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text("3. Preparar cartão").font(.headline)
                ProgressView(value: model.progress)
                Text(model.status).font(.callout).foregroundStyle(.secondary)
                Button {
                    model.showConfirmation = true
                } label: {
                    Label("Formatar FAT32 e instalar CNX", systemImage: "arrow.down.to.line.compact")
                        .frame(maxWidth: .infinity).padding(7)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.selected == nil || model.busy)
                Spacer(minLength: 0)
                Text("ATENÇÃO: a instalação limpa apaga todos os dados do cartão. Faça backup da emuMMC, Nintendo, saves e demais arquivos antes de continuar.")
                    .font(.caption).foregroundStyle(.orange)
            }
            .padding(24)
            .frame(minWidth: 550, minHeight: 515)
            .onAppear { model.refresh() }
            .alert("Apagar todos os dados do cartão?", isPresented: $model.showConfirmation) {
                Button("Cancelar", role: .cancel) {}
                Button("Apagar e instalar", role: .destructive) { model.install() }
            } message: {
                Text("Unidade: \(model.selected?.description ?? "nenhuma"). Esta operação APAGA TODO o conteúdo, incluindo emuMMC, jogos e backups. Não existe desfazer.")
            }
            .alert("Resultado", isPresented: $model.showResult) {
                Button("OK") {}
            } message: { Text(model.result) }
        }
        .windowResizability(.contentSize)
    }
}
