# Webshare Manager

Neoficiální aplikace pro Webshare.cz pro **macOS 14 a novější, Apple Silicon (M1 a novější)**.

## Stažení

Aplikaci stáhnete v [GitHub Releases](https://github.com/humaxdragon-bit/webshare-manager/releases). Rozbalte ZIP a přesuňte Webshare Manager do složky Aplikace.

**Současné vydání je testovací. Aplikace zatím nemá podpis Developer ID ani notarizaci od Applu.** Na jiném Macu proto může macOS zobrazit upozornění při otevření. Intel Macy zatím nejsou podporované.

## Ukázky rozhraní

Přehled přenosů a veřejné vyhledávání v tmavém vzhledu. Screenshoty jsou oříznuté na hlavní část okna, aby neobsahovaly údaje účtu.

![Přehled přenosů ve Webshare Manageru](docs/screenshots/transfers.png)

![Veřejné vyhledávání na Webshare](docs/screenshots/search.png)

## Co aplikace umí

- Hromadné stahování z odkazů a hromadné nahrávání souborů.
- Fronta s průběhem, rychlostí a 1–5 souběžnými přenosy.
- Procházení nahraných souborů, složek a podsložek na účtu Webshare.
- Veřejné hledání, kategorie, řazení a výběr více výsledků ke stažení.
- Kopírování odkazů a zobrazení stažených souborů ve Finderu.
- Moderní rozhraní se světlým i tmavým vzhledem podle macOS.
- České a slovenské rozhraní včetně horních nabídek. Jazyk se zvolí podle nastavení macOS; výchozí jazyk je čeština.
- Nabídka **Webshare Manager → Zkontrolovat aktualizace…** pro stažení a instalaci nových verzí.

Přihlášení probíhá přímo účtem Webshare.cz. Heslo se neukládá; přihlášení lze zapamatovat v Klíčence macOS. Nastavení a fronta zůstávají v uživatelské složce aplikace. Žádné uživatelské údaje ani soubory nejsou součástí tohoto repozitáře.

## Nahrávání do složky

V **Moje soubory** otevřete cílovou složku a klikněte na **Nahrát sem**. Vybrané soubory se přidají do fronty s touto cílovou složkou. Cíl je uvedený u každého nahrávání a nezmění se při dalším procházení složek. Tlačítko **Nahrát soubory** v přenosech a v přehledu všech souborů nahrává do hlavní složky.

## Aktualizace

Aktualizace se stahují z GitHub Releases. Jejich podpis se ověřuje před rozbalením. Instalace počká na dokončení probíhajících přenosů a aplikaci restartuje. Volba automatických kontrol se řídí nastavením aktualizačního systému.

Starší vydání bez této nabídky je potřeba jednou nahradit novým balíčkem ručně. Podpis aktualizací nenahrazuje podpis Developer ID a notarizaci od Applu.

## Omezení

Zastavený přenos se znovu spouští od začátku. Složky je nutné před nahráním zabalit do archivu. Stažení souborů chráněných samostatným heslem zatím není podporované. Limity služby a účtu Webshare se nemění.

## Sestavení a kontroly

Vyžaduje Swift 6, macOS SDK a Python 3. Závislosti stáhne Swift Package Manager.

```sh
./scripts/test.sh
./scripts/build-app.sh
```

Výstup je `dist/Webshare Manager.app` a `dist/Webshare-Manager-macOS.zip`.

Kontroly zahrnují hashování hesel, parsování seznamů a složek, překrývající se dotazy hledání, síťové stahování s průběhem a zrušení přenosu. Vygenerování ikony: `swift scripts/generate-icon.swift` a `iconutil -c icns .build/Manager.iconset -o Assets/WebshareManager.icns`.

## Vydání nové verze

1. Upravte číslo verze a sestavení v `scripts/build-app.sh` a poznámky v `updates/release-notes.txt`.
2. Proveďte commit a push zdrojového kódu do hlavní větve.
3. Na Macu s původním podpisovým klíčem v Klíčence spusťte `./scripts/publish-release.sh`.

Skript provede kontroly, sestaví aplikaci, podepíše archiv, zveřejní testovací vydání a aktualizuje informační soubor pro aplikaci. Privátní klíč zůstává v Klíčence, do repozitáře patří pouze veřejný klíč z `updates/config.json`. Záloha podpisového klíče se má uchovávat bezpečně mimo repozitář.

## Chyby a návrhy

Našli jste chybu nebo máte nápad na vylepšení? Otevřete [GitHub Issue](https://github.com/humaxdragon-bit/webshare-manager/issues/new/choose). K dispozici jsou české formuláře pro hlášení chyb a návrhy funkcí. Před odesláním zkontrolujte, zda už stejné téma neexistuje. U chyb uveďte verzi aplikace, macOS a postup pro zopakování; nesdílejte přihlašovací údaje ani soukromé odkazy.

## Licence

Projekt je dostupný pod [licencí MIT](LICENSE). Aplikaci můžete používat, upravovat a šířit při zachování licenčního a autorského oznámení. Licence součástí třetích stran jsou uvedené samostatně níže.

## Použité součásti

Aktualizace zajišťuje [Sparkle](https://sparkle-project.org/) pod licencí MIT. Licenční podmínky jsou přiložené v [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) a v sestavené aplikaci.

Projekt není oficiální aplikací služby Webshare.cz a není s ní organizačně spojený.
