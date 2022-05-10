# koha-plugin-rest-di

This is a REST API plugin for Koha. It provides extended API support for Discovery Interfaces such as VuFind.

Most of the functionality has been ported from the KohaSuomi version of Koha (see  https://github.com/KohaSuomi/Koha).

Note that this plugin requires Koha functionality that is only available from Koha 22.05. Releases for older versions are also available.

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
4. Add data for the plugin to Koha's MySQL database:

        insert into plugin_methods (plugin_class, plugin_method) values 
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'abs_path'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'api_namespace'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'api_routes'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'as_heavy'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'bundle_path'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'canonpath'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'catdir'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'catfile'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'curdir'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'decode_json'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'disable'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'enable'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'except'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'export'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'export_fail'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'export_ok_tags'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'export_tags'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'export_to_level'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'file_name_is_absolute'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'get_metadata'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'get_plugin_dir'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'get_plugin_http_path'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'get_qualified_table_name'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'get_template'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'go_home'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'import'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'is_enabled'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'max'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'mbf_dir'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'mbf_exists'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'mbf_open'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'mbf_path'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'mbf_read'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'mbf_validate'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'new'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'no_upwards'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'only'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'output'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'output_html'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'output_html_with_http_headers'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'output_with_http_headers'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'path'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'plugins'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'require_version'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'retrieve_data'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'rootdir'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'search_path'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'store_data'),
            ('Koha::Plugin::Fi::KohaSuomi::DI', 'updir');

## Building a Release

Travis will build the release provided the commit includes a suitable version tag:

1. `git tag -a vX.Y.Z -m "Release X.Y.Z"` (Feel free to provide a longer message too, it's displayed on the Releases page)
2. `git push --tags origin master`

To manually build a release locally, run `./build.sh`.

