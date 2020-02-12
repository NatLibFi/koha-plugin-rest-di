# koha-plugin-rest-di

This is a REST API plugin for Koha. It provides extended API support for Discovery Interfaces such as VuFind.

Most of the functionality has been ported from the KohaSuomi version of Koha (see  https://github.com/KohaSuomi/Koha).

Note that this plugin requires Koha functionality that is only available from Koha 20.05.

Note also that not all the functionality has been thoroughly tested yet.

## Downloading

You can download the relevant *.kpz file from the [release page](https://github.com/NatLibFi/koha-plugin-rest-di/releases).

## Installing

The plugin is installed by uploading the KPZ (Koha Plugin Zip) package of a released version on the Manage Plugins page of the Koha staff interface.

To set up the Koha plugin system you must first make some changes to your install:

1. Change `<enable_plugins>0<enable_plugins>` to ` <enable_plugins>1</enable_plugins>` in your koha-conf.xml file.
2. Confirm that the path to `<pluginsdir>` exists, is correct, and is writable by the web server.
3. Restart your webserver.

Once the setup is complete you will need to enable plugins by setting UseKohaPlugins system preference to 'Enable'.

You can upload and configure the plugin on the Administration -> Plugins -> Manage Plugins page.

### Installing without a KPZ package

If you need to use the plugin without a KPZ package (e.g. to use a version cloned from git):

1. As above, make sure the plugin system is configured and enabled.
2. Create the path Koha/Plugin/Fi/KohaSuomi/ under the ` <pluginsdir>`
3. Symlink the DI.pm file and DI directory to the Koha/Plugin/Fi/KohaSuomi/ directory.

## Building a Release

Travis will build the release provided the commit includes a suitable version tag:

1. `git tag -a vX.Y.Z -m "Release X.Y.Z"` (Feel free to provide a longer message too, it's displayed on the Releases page)
2. `git push --tags origin master`

To manually build a release locally, run `./build.sh`.