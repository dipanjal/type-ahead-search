# Maintainer: Dipanjal Maitra
# Contact: dipanjal.maitra@monstar-lab.com

DOCKER_NETWORK = type-ahead-search_default
ENV_FILE = assembler/hadoop/hadoop.env
HADOOP_BASE_IMAGE_TAG = mlbd/hadoop-base:latest

run:
	docker-compose up -d --build
logs:
	docker-compose logs --follow
stop:
	docker-compose down \
	&& docker rm $$(docker ps -a -q)
clear:
	make stop \
	&& docker system prune --all --force
setup:
	docker build -t ${HADOOP_BASE_IMAGE_TAG} ./assembler/hadoop/base

	while [[ "$$(echo "stat" | nc localhost 2181 | grep Mode)" != "Mode: standalone" ]] ; do \
	    echo "Waiting for zookeeper to come online" ; \
	    sleep 2 ; \
	done

	docker exec zookeeper ./bin/zkCli.sh -server localhost:2181 create /phrases ""
	docker exec zookeeper ./bin/zkCli.sh -server localhost:2181 create /phrases/assembler ""
	docker exec zookeeper ./bin/zkCli.sh -server localhost:2181 create /phrases/assembler/last_built_target ""

	docker exec zookeeper ./bin/zkCli.sh -server localhost:2181 create /phrases/distributor ""
	docker exec zookeeper ./bin/zkCli.sh -server localhost:2181 create /phrases/distributor/current_target ""
	docker exec zookeeper ./bin/zkCli.sh -server localhost:2181 create /phrases/distributor/next_target ""

	while [[ $$(curl -s -o /dev/null -w %{http_code} http://localhost:9870/) -ne "200" ]] ; do \
	    echo "Waiting for hadoop's namenode to come online" ; \
	    sleep 2 ; \
	done

	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} ${HADOOP_BASE_IMAGE_TAG} hadoop fs -mkdir -p /phrases/1_sink/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} ${HADOOP_BASE_IMAGE_TAG} hadoop fs -mkdir -p /phrases/2_with_weight/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} ${HADOOP_BASE_IMAGE_TAG} hadoop fs -mkdir -p /phrases/3_with_weight_merged/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} ${HADOOP_BASE_IMAGE_TAG} hadoop fs -mkdir -p /phrases/4_with_weight_ordered/
	docker run --network ${DOCKER_NETWORK} --env-file ${ENV_FILE} ${HADOOP_BASE_IMAGE_TAG} hadoop fs -mkdir -p /phrases/5_tries/

