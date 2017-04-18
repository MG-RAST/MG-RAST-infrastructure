#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
if [ "${1:0:1}" = '-' ]; then
	set -- cassandra -f "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'cassandra' -a "$(id -u)" = '0' ]; then
	chown -R cassandra /var/lib/cassandra /var/log/cassandra "$CASSANDRA_CONFIG"
	exec gosu cassandra "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'cassandra' ]; then
	: ${CASSANDRA_RPC_ADDRESS='0.0.0.0'}

	: ${CASSANDRA_LISTEN_ADDRESS='auto'}
	if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
		CASSANDRA_LISTEN_ADDRESS="$(hostname --ip-address)"
	fi

	: ${CASSANDRA_BROADCAST_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"}

	if [ "$CASSANDRA_BROADCAST_ADDRESS" = 'auto' ]; then
		CASSANDRA_BROADCAST_ADDRESS="$(hostname --ip-address)"
	fi
	: ${CASSANDRA_BROADCAST_RPC_ADDRESS:=$CASSANDRA_BROADCAST_ADDRESS}

	if [ -n "${CASSANDRA_NAME:+1}" ]; then
		: ${CASSANDRA_SEEDS:="cassandra"}
	fi
	: ${CASSANDRA_SEEDS:="$CASSANDRA_BROADCAST_ADDRESS"}
	
	sed -r 's/(- seeds:).*/\1 "'"$CASSANDRA_SEEDS"'"/' "$CASSANDRA_CONFIG/cassandra.yaml" > "$CASSANDRA_CONFIG/cassandra.yaml_part"
	cp "$CASSANDRA_CONFIG/cassandra.yaml_part" "$CASSANDRA_CONFIG/cassandra.yaml"

	for yaml in \
		broadcast_address \
		broadcast_rpc_address \
		cluster_name \
		endpoint_snitch \
		listen_address \
		num_tokens \
		rpc_address \
		start_rpc \
		storage_port \
		ssl_storage_port \
		native_transport_port \
		rpc_port \
		read_request_timeout_in_ms \
        range_request_timeout_in_ms \
        write_request_timeout_in_ms \
        counter_write_request_timeout_in_ms \
        cas_contention_timeout_in_ms \
        truncate_request_timeout_in_ms \
        request_timeout_in_ms \
        slow_query_log_timeout_in_ms \
        cross_node_timeout \
        streaming_keep_alive_period_in_secs \
        compaction_large_partition_warning_threshold_mb \
        batch_size_warn_threshold_in_kb \
        batch_size_fail_threshold_in_kb \
        gc_warn_threshold_in_ms \
	; do
		var="CASSANDRA_${yaml^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -r 's/^(# )?('"$yaml"':).*/\2 '"$val"'/' "$CASSANDRA_CONFIG/cassandra.yaml" > "$CASSANDRA_CONFIG/cassandra.yaml_temp"
			cp "$CASSANDRA_CONFIG/cassandra.yaml_temp" "$CASSANDRA_CONFIG/cassandra.yaml"
		fi
	done

	for rackdc in dc rack; do
		var="CASSANDRA_${rackdc^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -r 's/^('"$rackdc"'=).*/\1 '"$val"'/' "$CASSANDRA_CONFIG/cassandra-rackdc.properties" > "$CASSANDRA_CONFIG/cassandra-rackdc.properties_temp"
			cp "$CASSANDRA_CONFIG/cassandra-rackdc.properties_temp" "$CASSANDRA_CONFIG/cassandra-rackdc.properties"
		fi
	done
fi

exec "$@"
