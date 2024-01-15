# Changelog

All notable changes to Squoosh will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security

## [0.4.1]
### Fixed
- Build with more recent Nokogiri versions

## [0.4.0] - 2021-08-22
### Added
- Support for Ruby 3.0 (`execjs` needed a fix before this could happen)
### Changed
- HTML parsing is now done via Nokogiri rather than Nokogumbo (Nokogumbo was
  merged into Nokogiri)
### Removed
- Support for Ruby 2.5 (EOL)

## [0.3.2] - 2020-08-25
### Changed
- Changed minimum supported Ruby version to 2.5
### Fixed
- Omit `colgroup` start and end tags

## [0.3.1] - 2019-08-23
### Fixed
- Preserve attribute namespaces in foreign elements (`svg`, `math`)

## [0.3.0] - 2019-08-22
### Added
- Tests for CSS minification
- Tests for JavaScript minification
- Tests for not omitting end tags when configured not to
- Many other tests
### Changed
- Updated Sassc to version 2.1
### Fixed
- Fixed handling of leading newlines in `pre` and `textarea` elements
- Do not emit an end tag after a self-closing tag
- Do not emit `</script` inside of a `script` element

## [0.2.1] - 2019-03-27
### Changed
- Switched from deprecated Sass gem to Sassc

## [0.2.0] - 2018-10-12
### Added
- Documentation

### Changed
- Updated Nokogumbo to version 2.0

### Fixed
- Inline style sheet compression no longer cuts off the final character
