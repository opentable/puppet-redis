# == Define: redis::instance
#
# Configure redis instance on an arbitrary port.
#
# === Parameters
#
# [*redis_port*]
#   Accept redis connections on this port.
#   Default: 6379
#
# [*redis_bind_address*]
#   Address to bind to.
#   Default: false, which binds to all interfaces
#
# [*redis_max_memory*]
#   Maximum memory to be addressed by instance
#   Default: 4gb
#
# [*redis_max_clients*]
#   Set the redis config value maxclients. If no value provided, it is
#   not included in the configuration for 2.6+ and set to 0 (unlimited)
#   for 2.4.
#   Default: 0 (2.4)
#   Default: nil (2.6+)
#
# [*redis_timeout*]
#   Set the redis config value timeout (seconds).
#   Default: 300
#
# [*redis_loglevel*]
#   Set the redis config value loglevel. Valid values are debug,
#   verbose, notice, and warning.
#   Default: notice
#
# [*redis_databases*]
#   Set the redis config value databases.
#   Default: 16
#
# [*redis_slowlog_log_slower_than*]
#   Set the redis config value slowlog-log-slower-than (microseconds).
#   Default: 10000
#
# [*redis_showlog_max_len*]
#   Set the redis config value slowlog-max-len.
#   Default: 1024
#
# [*redis_password*]
#   Password used by AUTH command. Will be set if its not nil.
#   Default: nil
#
# [*redis_is_slave*]
#   Specify whether instance is a slave.
#   Default: false
#
# [*redis_slaveof_master_ip*]
#   IP address of master instance that this slave replicates.
#   Default: localhost
#
# [*redis_slaveof_master_port*]
#   Port that master instance is listening on.
#   Default: 6379
#
# [*redis_repl_backlog_size*]
#   Size of backlog buffer used to accumulate slave data when slaves are disconnected.
#   Default: 1Mb
#
# [*redis_slave_priority*]
#   Used by Redis Sentinel to select a slave to promote to master.
#   A slave with a low priority number is considered better for promotion.
#   However a special priority of 0 marks the slave as not able to perform
#   the role of master.
#   Default: 100
#
# [*redis_slave_output_buffer_hard_limit*]
#   Hard limit on the size of the slave replication buffer.
#   Default: 256mb
#
# [*redis_slave_output_buffer_soft_limit*]
#   Soft limit on the size of the slave replication buffer.
#   Default: 64mb
#
# [*redis_slave_output_buffer_soft_limit_max_interval*]
#   Upper bound on the time interval during which the slave replication buffer continuously exceeds the soft limit.
#   Default: 60s
#
# === Examples
#
# redis::instance { 'redis-6900':
#   redis_port       => '6900',
#   redis_max_memory => '64gb',
# }
#
# === Authors
#
# Thomas Van Doren
#
# === Copyright
#
# Copyright 2012 Thomas Van Doren, unless otherwise noted.
#
define redis::instance (
  $redis_port = $redis::params::redis_port,
  $redis_bind_address = $redis::params::redis_bind_address,
  $redis_max_memory = $redis::params::redis_max_memory,
  $redis_maxmemory_policy = $redis::params::redis_maxmemory_policy,
  $redis_max_clients = $redis::params::redis_max_clients,
  $redis_timeout = $redis::params::redis_timeout,
  $redis_loglevel = $redis::params::redis_loglevel,
  $redis_databases = $redis::params::redis_databases,
  $redis_slowlog_log_slower_than = $redis::params::redis_slowlog_log_slower_than,
  $redis_slowlog_max_len = $redis::params::redis_slowlog_max_len,
  $redis_password = $redis::params::redis_password,
  $redis_is_slave = $redis::params::redis_is_slave,
  $redis_slaveof_master_ip = $redis::params::redis_slaveof_master_ip,
  $redis_slaveof_master_port = $redis::params::redis_slaveof_master_port,
  $redis_repl_backlog_size = $redis::params::redis_repl_backlog_size,
  $redis_slave_priority = $redis::params::redis_slave_priority,
  $redis_slave_output_buffer_hard_limit = $redis::params::redis_slave_output_buffer_hard_limit,
  $redis_slave_output_buffer_soft_limit = $redis::params::redis_slave_output_buffer_soft_limit,
  $redis_slave_output_buffer_soft_limit_max_interval = $redis::params::redis_slave_output_buffer_soft_limit_max_interval,
  $redis_snapshotting = $redis::params::redis_snapshotting,
  $redis_notify_keyspace_events = $redis::params::redis_notify_keyspace_events,
  $restart_service_on_change = $redis::params::restart_service_on_change,
  $manage_config_file = $redis::params::manage_config_file
) {

  # Using Exec as a dependency here to avoid dependency cyclying when doing
  # Class['redis'] -> Redis::Instance[$name]
  Exec['install-redis'] -> Redis::Instance[$name]
  include ::redis

  $version = $redis::version

  case $version {
    /^2\.4\.\d+$/: {
      if ($redis_max_clients == false) {
        $real_redis_max_clients = 0
      }
      else {
        $real_redis_max_clients = $redis_max_clients
      }
    }
    /^2\.[68]\.\d+$/: {
      $real_redis_max_clients = $redis_max_clients
    }
    default: {
      fail("Invalid redis version, ${version}. It must match 2.4.\\d+ or 2.[68].\\d+.")
    }
  }

  if !empty($redis_notify_keyspace_events) and versioncmp($version, '2.8.0') < 0 {
    fail("This version (${version}) of redis does not support the notify_keyspace_events config option.  Must be >= 2.8.0")
  }

  file { "redis-lib-port-${redis_port}":
    ensure => directory,
    path   => "/var/lib/redis/${redis_port}",
  }

  if $facts['service_provider'] == 'systemd'{
    $service_file = "service-redis-${redis_port}"
    file { $service_file:
      ensure  => file,
      path    => "/etc/systemd/system/redis_${redis_port}.service",
      content => template('redis/redis.service.erb'),
      mode    => '0755',
      replace => true,
    }
  } else {
    $service_file = "redis-init-${redis_port}"
    file { $service_file:
      ensure  => file,
      path    => "/etc/init.d/redis_${redis_port}",
      mode    => '0755',
      content => template('redis/redis.init.erb'),
      replace => true,
    }
  }

  file { "redis_port_${redis_port}.conf":
    ensure  => file,
    path    => "/etc/redis/${redis_port}.conf",
    mode    => '0644',
    content => template('redis/redis_port.conf.erb'),
    replace => $manage_config_file,
  }

  $service_subscribe = $restart_service_on_change ? {
    true    => [ File["redis_port_${redis_port}.conf"], File[$service_file] ],
    default => [],
  }

  service { "redis-${redis_port}":
    ensure    => running,
    name      => "redis_${redis_port}",
    enable    => true,
    require   => [ File["redis_port_${redis_port}.conf"], File[$service_file], File["redis-lib-port-${redis_port}"] ],
    subscribe => $service_subscribe,
  }

}
