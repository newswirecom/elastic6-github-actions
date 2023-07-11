#!/bin/bash

set -euxo pipefail

if [[ -z $STACK_VERSION ]]; then
  echo -e "\033[31;1mERROR:\033[0m Required environment variable [STACK_VERSION] not set\033[0m"
  exit 1
fi

MAJOR_VERSION=`echo ${STACK_VERSION} | cut -c 1`

docker network create elastic6

mkdir -p /es/plugins/
chown -R 1000:1000 /es/

if [ "x${MAJOR_VERSION}" != 'x6' ]; then
  echo "Only for Elasticsearch 6"
  exit 1
fi

if [[ ! -z $PLUGINS ]]; then
  docker run --rm \
    --network=elastic6 \
    -v /es/plugins/:/usr/share/elasticsearch/plugins/ \
    --entrypoint=/usr/share/elasticsearch/bin/elasticsearch-plugin \
    docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION} \
    install ${PLUGINS/\\n/ } --batch
fi

for (( node=1; node<=${NODES-1}; node++ ))
do
  port_com=$((9300 + $node - 1))
  UNICAST_HOSTS+="es6-$node:${port_com},"
done

for (( node=1; node<=${NODES-1}; node++ ))
do
  port=$((PORT + $node - 1))
  port_com=$((9300 + $node - 1))
  docker run \
    --rm \
    --env "node.name=es6-${node}" \
    --env "cluster.name=docker-elastic6" \
    --env "cluster.routing.allocation.disk.threshold_enabled=false" \
    --env "bootstrap.memory_lock=true" \
    --env "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
    --env "xpack.security.enabled=false" \
    --env "xpack.license.self_generated.type=basic" \
    --env "discovery.zen.ping.unicast.hosts=${UNICAST_HOSTS}" \
    --env "discovery.zen.minimum_master_nodes=${NODES}" \
    --env "http.port=${port}" \
    --ulimit nofile=65536:65536 \
    --ulimit memlock=-1:-1 \
    --publish "${port}:${port}" \
    --publish "${port_com}:${port_com}" \
    --detach \
    --network=elastic6 \
    --name="es6-${node}" \
    -v /es/plugins/:/usr/share/elasticsearch/plugins/ \
    docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
done

sleep 10

echo "Elasticsearch 6 up and running"
