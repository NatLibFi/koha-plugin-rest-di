# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [23.05.06] - 2023-10-10

### Changed

- auth/patrons/validation now uses Koha's checkpw method to ensure that all required checks are performed (and also adds support for LDAP etc.).
- Successful patron validation using the auth/patrons/validation endpoint now updates the lastseen field using Koha's track_login_daily method.

## [23.05.05] - 2023-10-10

### Fixed

- Fixed an error that occurred when checking for biblio holdability when the patron already had an item level hold for the biblio.

## [23.05.04] - 2023-09-19

### Changed

- Added a query parameter that allows one to include found holds in the hold queue length.

## [23.05.03] - 2023-09-18

### Fixed

- Hold queue length calculation now takes only non-found holds into account.

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
