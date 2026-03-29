# Changelog

## [1.5.4](https://github.com/matjam/headroom/compare/v1.5.3...v1.5.4) (2026-03-29)


### Bug Fixes

* use semver for CFBundleVersion, show git SHA separately ([cc4b422](https://github.com/matjam/headroom/commit/cc4b422fec1203d76147b7dd9dcb263b3f9334e5))
* use semver for CFBundleVersion, show git SHA separately ([5191702](https://github.com/matjam/headroom/commit/5191702764e57b633334face792e5bc2c1731439))

## [1.5.3](https://github.com/matjam/headroom/compare/v1.5.2...v1.5.3) (2026-03-29)


### Bug Fixes

* use git short SHA as build number ([40f8493](https://github.com/matjam/headroom/commit/40f8493ed5d88365f6a701c25a219c231adad4d5))
* use git short SHA as build number instead of duplicating version ([1308a60](https://github.com/matjam/headroom/commit/1308a6056450e27a496e2bbaf0fe420a5a95c314))

## [1.5.2](https://github.com/matjam/headroom/compare/v1.5.1...v1.5.2) (2026-03-29)


### Bug Fixes

* fetch tags in CI so version is stamped from git tag ([d11db1a](https://github.com/matjam/headroom/commit/d11db1a9569bb754f0f610f304239da5b1572d3a))
* stamp version from git tags and fetch tags in CI ([7d7fcd1](https://github.com/matjam/headroom/commit/7d7fcd1f15f8fae679ed5653f4f933491b200e82))

## [1.5.1](https://github.com/matjam/headroom/compare/v1.5.0...v1.5.1) (2026-03-29)


### Bug Fixes

* add MARKETING_VERSION defaults so Info.plist version placeholders resolve ([6a8d456](https://github.com/matjam/headroom/commit/6a8d4564746789fc7ace85d3ad7e0b2f5e291afd))
* resolve Info.plist version placeholders for Sparkle updates ([4911187](https://github.com/matjam/headroom/commit/49111872d2a58c04a26a37a159a309b89ea3ff75))

## [1.5.0](https://github.com/matjam/headroom/compare/v1.4.0...v1.5.0) (2026-03-29)


### Features

* show version number in settings, derive from git tags ([7d64dd4](https://github.com/matjam/headroom/commit/7d64dd4607d95cbc56a667c1a29b1e3a0d925095))
* version from git tags + fix Sparkle codesigning ([62366c0](https://github.com/matjam/headroom/commit/62366c0fe7e25db6f8b73bb61db2b92bc9e9a722))

## [1.4.0](https://github.com/matjam/headroom/compare/v1.3.0...v1.4.0) (2026-03-29)


### Features

* show version number in settings, derive from git tags ([84abf59](https://github.com/matjam/headroom/commit/84abf5964b5fddb0fbf52edf344a85c2ec305d89))
* show version number in settings, remove Done button ([0196ed5](https://github.com/matjam/headroom/commit/0196ed511e2d6465230457715feb1d3efe884e5f))

## [1.3.0](https://github.com/matjam/headroom/compare/v1.2.1...v1.3.0) (2026-03-29)


### Features

* show version number in settings, remove Done button ([3f0f998](https://github.com/matjam/headroom/commit/3f0f998ba24bac26e9e6b4e32a9947c38eeffa56))
* show version number in settings, remove Done button ([bb6512a](https://github.com/matjam/headroom/commit/bb6512a093d2d8cc04c8ea7325ce99dfdb9551f9))

## [1.2.1](https://github.com/matjam/headroom/compare/v1.2.0...v1.2.1) (2026-03-29)


### Bug Fixes

* deep re-sign Sparkle framework binaries for notarization ([41a540d](https://github.com/matjam/headroom/commit/41a540d626812273db3aa57b0935f72608afb3e3))
* deep re-sign Sparkle framework binaries with Developer ID ([17fd6cb](https://github.com/matjam/headroom/commit/17fd6cbafd473a06b2a569ae719c6b422521ed65))

## [1.2.0](https://github.com/matjam/headroom/compare/v1.1.3...v1.2.0) (2026-03-29)


### Features

* add Sparkle auto-update support ([f622e25](https://github.com/matjam/headroom/commit/f622e25d19dcdb3e117745696ce97a120e89b591))
* Sparkle auto-update support ([2282453](https://github.com/matjam/headroom/commit/2282453f9a3045e748ca03741299822002bf7e38))

## [1.1.3](https://github.com/matjam/headroom/compare/v1.1.2...v1.1.3) (2026-03-29)


### Bug Fixes

* strip get-task-allow entitlement from release builds ([b46cbc3](https://github.com/matjam/headroom/commit/b46cbc33ab888a43b4dee42df1d39408799b0fb3))
* strip get-task-allow entitlement from release builds ([7a5c2f6](https://github.com/matjam/headroom/commit/7a5c2f62396073b6cdb3ec06d8700994e3051ea8))

## [1.1.2](https://github.com/matjam/headroom/compare/v1.1.1...v1.1.2) (2026-03-29)


### Bug Fixes

* add secure timestamp and notarization log on failure ([6bf26ab](https://github.com/matjam/headroom/commit/6bf26ab3c48a9c625773fa1a276e59edb3773649))
* add secure timestamp to release signing and fetch notarization log on failure ([65e7215](https://github.com/matjam/headroom/commit/65e7215df38319b5856bcb19591340b74683ddac))

## [1.1.1](https://github.com/matjam/headroom/compare/v1.1.0...v1.1.1) (2026-03-29)


### Bug Fixes

* resolve code signing conflict in release builds ([9476cf8](https://github.com/matjam/headroom/commit/9476cf81a2e075cd11cee29b05238276d3026a4a))
* resolve code signing conflict in release builds ([c2a184d](https://github.com/matjam/headroom/commit/c2a184da3a6f2ff7ee08d5d3fbd4c0073150c564))

## [1.1.0](https://github.com/matjam/headroom/compare/v1.0.0...v1.1.0) (2026-03-29)


### Features

* Developer ID signing and notarization for releases ([ae74e8e](https://github.com/matjam/headroom/commit/ae74e8e3d2e7f50b8e72918b25f07a9a70970098))
* Developer ID signing and notarization for releases ([31efc87](https://github.com/matjam/headroom/commit/31efc875614751b1761fa6a4903640652b32ae07))

## 1.0.0 (2026-03-29)


### Features

* add code signing to release workflow ([e5d53a0](https://github.com/matjam/headroom/commit/e5d53a0a189c17ff2ee48e43e2d28a97a1de36b7))
* initial release of Headroom - Claude.ai usage monitor for the macOS menu bar ([5b48c95](https://github.com/matjam/headroom/commit/5b48c9529244b9933601a235118e31b6633c4cba))


### Bug Fixes

* allow unsigned CI builds when DEVELOPMENT_TEAM is not set ([438d148](https://github.com/matjam/headroom/commit/438d1486b3c5e54daf47300a7028ce5588f0fcde))
