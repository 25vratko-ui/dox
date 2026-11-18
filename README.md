# Dox

Prémiový prídavný dock pre macOS: aplikácie, priečinky, súbory a odkazy zoskupené do kategórií,
s veľmi hlbokou kustomizáciou. Natívny Swift / SwiftUI + AppKit, macOS 14+.

## Čo vie
- **Viac dockov naraz**, každý na ľubovoľnej hrane (vľavo, vpravo, hore, dole), na hlavnom displeji,
  na displeji s myšou, na konkrétnom displeji alebo na všetkých.
- **Kategórie**: názov, SF Symbol ikona, farba, skrytie, režim „zložená do jednej ikony“ s popoverom.
  Hlavičky kategórií ako medzera, čiara, farebná kapsula alebo názov.
- **Položky**: aplikácie, priečinky (stack ako mriežka / zoznam / vejár, triedenie), súbory, webové odkazy,
  oddeľovače a medzery. Drag & drop z Findera a prehliadača, preusporiadanie ťahaním aj medzi dockami.
- **Vzhľad**: 7 vstavaných tém (Obsidián, Mráz, Polárna žiara, Grafit, Žeravé uhlíky, Papier, Polnočný neón)
  + vlastné témy s importom/exportom. Materiál skla, tint, gradient, priehľadnosť, akcent, veľkosť a tvar ikon,
  tiene, okraje, zaoblenie, rozostupy, magnifikácia (sila aj dosah), efekty pri prejdení myšou, popisky,
  indikátor bežiacich appiek, rýchlosť animácií, svetlý/tmavý režim.
- **Rozloženie**: jeden rad, mriežka (počet radov), police podľa kategórií; zarovnanie, posun, odstup od hrany.
- **Správanie**: automatické skrývanie s oneskoreniami, režim „iba skratkou“, skrytie pri fullscreene,
  všetky Spaces, akcia kliknutia (⌥ klik robí opak), skrytie po spustení.
- **Skratky**: globálna skratka pre každý dock, pre všetky docky a pre nastavenia.
- Ikona v menu bare, spúšťanie pri prihlásení, export/import celej konfigurácie.

## Spustenie
```bash
swift build -c release      # alebo otvor Package.swift v Xcode a daj Run
./scripts/bundle.sh         # vytvorí build/Dox.app (ad-hoc podpis)
open build/Dox.app
```
Testy: `swift test`. Konfigurácia sa ukladá do `~/Library/Application Support/Dox/config.json`.

## Ako to vzniklo
Kód napísali Claude Code subagenti nainštalovaní v `.claude/agents` (zdroje v `.claude/agents/SOURCES.md`).
Architektúra je v `ARCHITECTURE.md`, vizuálny jazyk v `DESIGN.md`.
