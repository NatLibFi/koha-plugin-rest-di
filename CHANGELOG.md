# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [23.05.00] - 2023-05-29

This release bumps the required Koha version to 22.12. In practice a Koha build that contains commit ddc2906b is required.

### Fixed

- Fix compatibility with C4::Circulation::CanBookBeRenewed and C4::Reserves::CheckReserves (#27, see also Koha Bug 31735).