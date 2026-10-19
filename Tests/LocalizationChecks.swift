import Foundation
@main struct LocalizationChecks {
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sk = Bundle(url: root.appendingPathComponent("Resources/sk.lproj"))!
        let cs = Bundle(url: root.appendingPathComponent("Resources/cs.lproj"))!
        precondition(L("Stahování", bundle: sk) == "Sťahovanie")
        precondition(L("Moje soubory", bundle: sk) == "Moje súbory")
        precondition(L("Zkontrolovat aktualizace…", bundle: sk) == "Skontrolovať aktualizácie…")
        precondition(L("Stahování", bundle: cs) == "Stahování")
        precondition(L("user-file-name", bundle: sk) == "user-file-name")
        let counts = String(format: L("%lld z %lld načtených položek", bundle: sk), 12, 24)
        precondition(counts == "12 z 24 načítaných položiek")
        print("Načtení českých a slovenských textů i formátování počtů prošlo.")
    }
}
