# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [23.05.02] - 2023-08-08

### Fixed

- Biblio hold availability calculation was missing a check for existing item level holds for the patron.

### Changed

- Optimized biblio hold availability a tiny bit.

## [23.05.01] - 2023-08-07

### Fixed

- Reading and updating of patron information required more permissions than necessary. delete_borrowers permission is no longer required.
- hold_queue_length now always includes all holds regardless of whether a patron was specified.

## [23.05.00] - 2023-05-29

This release bumps the required Koha version to 22.12. In practice a Koha build that contains commit ddc2906b is required.

### Fixed

- Fix compatibility with C4::Circulation::CanBookBeRenewed and C4::Reserves::CheckReserves (#27, see also Koha Bug 31735).
