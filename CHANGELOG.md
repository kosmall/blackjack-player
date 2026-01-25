# Changelog

## [1.9.3] - 2026-01-25

### Fixed
- Trade button now properly targets the dealer before initiating trade
- Added fallback targeting if initial target fails
- Trade button no longer requires dealer to be pre-selected

## [1.9.2] - 2026-01-23

### Fixed
- Restored GitHub Actions workflow for CurseForge releases

## [1.9.1] - 2026-01-23

### Fixed
- Updated version number in addon code

## [1.9.0] - 2026-01-21

### Added
- Re-bet button support for push/draw situations
- After a push (tie), dealer offers re-bet option
- RE-BET button appears automatically when offered by dealer
- Clicking RE-BET sends 'rebet' command to continue with same bet

## [1.8.0] - 2026-01-15

### Added
- Spectator mode improvements
- Ability to watch other players' games when not actively playing
- Better tracking of current player being served

## [1.7.0] - 2026-01-10

### Improved
- Game state management
- Phase tracking (waiting, dealing, playerTurn, dealerTurn, finished)
- Current player tracking for multi-player support

## [1.6.0] - 2026-01-08

### Added
- Dealer card display improvements
- Hidden card visualization for dealer's second card

## [1.5.0] - 2026-01-07

### Fixed
- Various bug fixes and stability improvements

## [1.4.0] - 2026-01-06

### Improved
- UI layout adjustments
- Better button positioning

## [1.3.0] - 2025-01-05

### Added
- Voice announcements for Win and Blackjack results (MP3 files)

### Fixed
- Trade button now uses SecureActionButton to avoid protected function errors

## [1.2.0] - 2025-01-05

### Added
- Sound effects for game events:
  - New card dealt
  - Your turn notification
  - Win / Blackjack / Lose / Push results

## [1.1.0] - 2025-01-05

### Added
- Trade button to quickly initiate trade with dealer
- Button is disabled when no dealer is known, enabled after dealer sends first message

### Changed
- Adjusted button layout (HIT, TRADE, PASS) with smaller sizes for better fit

## [1.0.0] - 2025-01-03

### Added
- Initial release
- Card display interface with Hit/Stand buttons
- Automatic bet tracking via trade window
- Party/raid whisper communication with dealer
- Minimap button for quick access
