# Сборка проекта

Этот проект написан на Windows, поэтому `.xcodeproj` не сгенерирован —
Xcode для этого нужен macOS. Вместо ручного `.pbxproj` тут лежит
[XcodeGen](https://github.com/yonaskolb/XcodeGen)-конфиг `project.yml`,
который надёжнее собрать в реальный проект, чем писать бинарник руками.

**Своего Mac нет — и не нужен.** Сборку делает macOS-раннер в GitHub
Actions (`.github/workflows/ios.yml`), установку на iPhone — Sideloadly
с Windows. Пошагово это описано в [INSTALL.md](INSTALL.md).

## Если Mac всё-таки под рукой

```bash
brew install xcodegen
cd BetTracker
xcodegen generate
open BetTracker.xcodeproj
```

Дальше открывается обычный Xcode-проект: таргет `BetTracker` (iOS 17+),
таргет тестов `BetTrackerTests`. Собирается и запускается как любой
SwiftUI-проект — Cmd+R на симуляторе iPhone.

Если меняешь список файлов (добавляешь/удаляешь Swift-файлы) —
перезапусти `xcodegen generate`, он пересоберёт `.xcodeproj` из папок
`Sources/` и `Tests/`.

## Что реализовано (Этап 1)

- Модели SwiftData: `Bet`, `Tournament`, `Team`, `Match`, `BankTransaction`
- `StatsCalculator` — все расчёты профита/ROI/винрейта/баланса, ничего
  не хранится в базе, покрыто юнит-тестами
- Четыре экрана: Ставки, Турниры, Дашборд, Банк
- Добавление и редактирование ставок, смена статуса свайпом
- Добавление депозитов/выводов
- Сид-данные из `BET_STATS_05_09.xlsx` (через макет) — 20 ставок, банк,
  4 турнира с командами и матчами

Полностью офлайн, сети нет — как и требует Этап 1 в `SPEC.md`.
