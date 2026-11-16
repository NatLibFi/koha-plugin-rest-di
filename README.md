# koha-plugin-rest-di

This is a REST API plugin for Koha. It provides extended API support for Discovery Interfaces such as VuFind.

Note that this plugin requires Koha functionality that is only available from Koha 23.11. Releases for other versions are also available.

Most of the functionality has been ported from the KohaSuomi version of Koha (see  https://github.com/KohaSuomi/Koha).

Not all the functionality has been thoroughly tested yet.

See CHANGELOG.md for information about changes in this plugin.

## Downloading

You can download the relevant *.kpz file from the [release page](https://github.com/NatLibFi/koha-plugin-rest-di/releases).

Latest version may not support older Koha versions. Please choose an appropriate version.

## Installing

The plugin is installed by uploading the KPZ (Koha Plugin Zip) package of a released version on the Manage Plugins page of the Koha staff interface.

To set up the Koha plugin system you must first make some changes to your install:

1. Change `<enable_plugins>0<enable_plugins>` to ` <enable_plugins>1</enable_plugins>` in your koha-conf.xml file.
2. Confirm that the path to `<pluginsdir>` exists, is correct, and is writable by the web server.
3. Restart your webserver.

Once the setup is complete you will need to enable plugins by setting UseKohaPlugins system preference to 'Enable'.

You can upload and configure the plugin on the Administration -> Plugins -> Manage Plugins page.

### Required User Permissions

To use all the functionality the plugin provides, the following permissions are needed for the user account used to authenticate for the API:

 - circulate_remaining_permissions
 - catalogue
 - borrowers
   - edit_borrowers
   - view_borrower_infos_from_any_libraries
 - reserveforothers
 - modify_holds_priority
 - place_holds
 - updatecharges
   - payout
   - remaining_permissions

### Installing without a KPZ package

If you need to use the plugin without a KPZ package (e.g. to use a version cloned from git):

1. As above, make sure the plugin system is configured and enabled.
2. Create the path Koha/Plugin/Fi/KohaSuomi/ under the ` <pluginsdir>`
3. Symlink the DI.pm file and DI directory to the Koha/Plugin/Fi/KohaSuomi/ directory.
4. Add data for the plugin to Koha's MySQL database by running Koha's misc/devel/install_plugins.pl script from the command line.

## Building a Release

A GitHub Action will build the release provided the commit includes a suitable version tag:

1. `git tag -a vX.Y.Z -m "Release X.Y.Z"` (Feel free to provide a longer message too, it's displayed on the Releases page)
2. `git push --tags origin main`

To manually build a release locally, run `./build.sh`.

