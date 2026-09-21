# Generated site configurations

This directory is not the source of managed site configurations. The source
files are under `config/sites/` and `config/templates/`; GitHub Actions
renders them and installs the resulting `*.conf` files into the server's
`/etc/nginx/conf.d/` directory.

The legacy Docker gateway compose file may still refer to this directory, but
the production deployment uses the host Nginx service.
