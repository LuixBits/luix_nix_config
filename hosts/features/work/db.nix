{ pkgs, ... }:
{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb_114;

    settings.mysqld = {
      bind-address = "0.0.0.0";
      character-set-server = "utf8mb4";
      collation-server = "utf8mb4_unicode_ci";
      lower_case_table_names = 1;

      innodb_buffer_pool_size = "10G";
      innodb_buffer_pool_instances = 4;
      innodb_log_file_size = "2G";
      innodb_log_buffer_size = "512M";
      innodb_flush_neighbors = 0;

      max_connections = 100;
      thread_cache_size = 64;
      table_open_cache = 8000;
      table_definition_cache = 4000;

      innodb_flush_method = "O_DIRECT";
      innodb_flush_log_at_trx_commit = 2;
      innodb_io_capacity = 4000;
      innodb_io_capacity_max = 8000;
      innodb_read_io_threads = 8;
      innodb_write_io_threads = 8;
      innodb_file_per_table = 1;
      innodb_buffer_pool_load_at_startup = 1;
      innodb_buffer_pool_dump_at_shutdown = 1;

      tmp_table_size = "128M";
      max_heap_table_size = "128M";
      query_cache_type = 0;
      query_cache_size = 0;

      slow_query_log = 1;
      slow_query_log_file = "/var/log/mysql/slow.log";
      long_query_time = 2;

      performance_schema = true;
      performance_schema_digests_size = 10000;
      performance_schema_max_table_instances = 10000;

      character_set_server = "utf8mb4";
      collation_server = "utf8mb4_unicode_ci";

      max_allowed_packet = "512M";
      connect_timeout = 10;
      wait_timeout = 600;
      interactive_timeout = 600;

      skip_name_resolve = true;
    };
  };

  # Credentials are intentionally not stored in git.
  # Add user/database bootstrap SQL from a local, untracked module if needed.

  networking.firewall.allowedTCPPorts = [ 3306 ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };
}
