# PHONY targets have no dependencies and they will be built unconditionally upon request.
.PHONY: generated-artifacts initialize-org0.example.com initialize-org1.example.com initialize-example.com initialize-www.example.com initialize inspect-initialized-volumes up up-detached logs-follow down down-full rm-state-volumes rm-node-modules rm-webserver-env rm-chaincode-docker-resources clean

# This is also hardcoded in .env, so if you change it here, you must change it there.  Note that
# it must be in all-lowercase, as docker-compose changes it to lowercase anyway.
COMPOSE_PROJECT_NAME := fabricwebapp

GENERATED_ARTIFACTS_VOLUME := $(COMPOSE_PROJECT_NAME)_generated_artifacts__volume
COM_EXAMPLE_ORG0_VOLUMES := $(COMPOSE_PROJECT_NAME)_com_example_org0_ca__volume $(COMPOSE_PROJECT_NAME)_com_example_org0_peer0__volume $(COMPOSE_PROJECT_NAME)_com_example_org0_peer1__volume
COM_EXAMPLE_ORG1_VOLUMES := $(COMPOSE_PROJECT_NAME)_com_example_org1_ca__volume $(COMPOSE_PROJECT_NAME)_com_example_org1_peer0__volume $(COMPOSE_PROJECT_NAME)_com_example_org1_peer1__volume
COM_EXAMPLE_VOLUMES := $(COMPOSE_PROJECT_NAME)_com_example_ca__volume $(COMPOSE_PROJECT_NAME)_com_example_orderer__volume
COM_EXAMPLE_WWW_VOLUMES := $(COMPOSE_PROJECT_NAME)_com_example_www__volume

# Default make rule
all:
	@echo "See README.md for info on make targets."

generated-artifacts:
	docker-compose -f docker/initialize.yaml up crypto_config
	docker-compose -f docker/initialize.yaml up channel_config
	# This removes stopped containers
	docker-compose -f docker/initialize.yaml rm --force
	# This command succeeds if and only if the specified volumes exist -- TODO: This doesn't actually check
	# what we want, because docker-compose creates all these volumes upon startup, regardless of what happens later.
	docker volume inspect $(GENERATED_ARTIFACTS_VOLUME)
# 	docker volume inspect $(COMPOSE_PROJECT_NAME)_generated_artifacts__volume

# TODO: Put failsafes in to prevent calling this twice?
initialize-org0.example.com:
	# This command succeeds if and only if the specified volumes exist
	docker volume inspect $(GENERATED_ARTIFACTS_VOLUME)
	docker-compose -f docker/initialize.yaml up com_example_org0__initialize
	# This removes stopped containers
	docker-compose -f docker/initialize.yaml rm --force
	# This command succeeds if and only if the specified volumes exist
	docker volume inspect $(COM_EXAMPLE_ORG0_VOLUMES)
# 	docker volume inspect $(COMPOSE_PROJECT_NAME)_com_example_org0_ca__volume $(COMPOSE_PROJECT_NAME)_com_example_org0_peer0__volume $(COMPOSE_PROJECT_NAME)_com_example_org0_peer1__volume

initialize-org1.example.com:
	# This command succeeds if and only if the specified volumes exist
	docker volume inspect $(GENERATED_ARTIFACTS_VOLUME)
	docker-compose -f docker/initialize.yaml up com_example_org1__initialize
	# This removes stopped containers
	docker-compose -f docker/initialize.yaml rm --force
	# This command succeeds if and only if the specified volumes exist
	docker volume inspect $(COM_EXAMPLE_ORG1_VOLUMES)
# 	docker volume inspect $(COMPOSE_PROJECT_NAME)_com_example_org1_ca__volume $(COMPOSE_PROJECT_NAME)_com_example_org1_peer0__volume $(COMPOSE_PROJECT_NAME)_com_example_org1_peer1__volume

initialize-example.com:
	# This command succeeds if and only if the specified volumes exist
	docker volume inspect $(GENERATED_ARTIFACTS_VOLUME)
	docker-compose -f docker/initialize.yaml up com_example__initialize
	# This removes stopped containers
	docker-compose -f docker/initialize.yaml rm --force
	# This command succeeds if and only if the specified volumes exist
	docker volume inspect $(COM_EXAMPLE_VOLUMES)
# 	docker volume inspect $(COMPOSE_PROJECT_NAME)_com_example_ca__volume $(COMPOSE_PROJECT_NAME)_com_example_orderer__volume

initialize-www.example.com:
	# This command succeeds if and only if the specified volumes exist
	docker volume inspect $(GENERATED_ARTIFACTS_VOLUME)
	docker-compose -f docker/initialize.yaml up com_example_www__initialize
	# This removes stopped containers
	docker-compose -f docker/initialize.yaml rm --force
	# This command succeeds if and only if the specified volumes exist
	docker volume inspect $(COM_EXAMPLE_WWW_VOLUMES)
# 	docker volume inspect $(COMPOSE_PROJECT_NAME)_com_example_www__volume

# Copies necessary materials from generated_artifacts__volume to the volumes for various peers/orderers/etc.
initialize: initialize-org0.example.com initialize-org1.example.com initialize-example.com initialize-www.example.com

# Note that this only checks for the presence of certain volumes.  It doesn't verify that the contents are correct.
inspect-initialized-volumes:
	docker volume inspect $(COM_EXAMPLE_ORG0_VOLUMES) $(COM_EXAMPLE_ORG1_VOLUMES) $(COM_EXAMPLE_VOLUMES) $(COM_EXAMPLE_WWW_VOLUMES) || echo "must successfully run `make initialize` in order to generate the containers needed for the various services."

# Bring up all services (and necessary volumes, networks, etc)
up: inspect-initialized-volumes
	docker-compose up --abort-on-container-exit

# Bring up all services (and necessary volumes, networks, etc) in detached mode
up-detached: inspect-initialized-volumes
	docker-compose up -d --abort-on-container-exit

# Follow the output of the logs
logs-follow:
	docker-compose logs --follow --tail="all"

# Bring down all services (delete associated containers, networks, but not volumes)
down:
	docker-compose down

# Bring down all services and volumes (delete associated containers, networks, AND volumes)
down-full:
	docker-compose down -v

# # Shows all non-source resources that this project created that currently still exist.
# # The shell "or" with `true` is so we don't receive the error code that find/grep produces when there are no matches.
# show-all-generated-resources:
# 	find generated-artifacts || true
# 	@echo ""
# 	docker ps -a | grep example.com || true
# 	@echo ""
# 	docker volume ls | grep $(COMPOSE_PROJECT_NAME) || true
# 	@echo ""
# 	docker images | grep -E "$(COMPOSE_PROJECT_NAME)|example.com" || true

# Delete the "state" volumes -- tmp dir (which contains the webserver's key store) and HFC key/value store in
# home dir This can be done after `make down` to reset things to a "clean state", without needing to recompile go code or
# run `npm install` from scratch.  The shell "or" with `true` is so this command never fails.
rm-state-volumes:
	docker volume rm \
	$(COM_EXAMPLE_ORG0_VOLUMES) \
	$(COM_EXAMPLE_ORG1_VOLUMES) \
	$(COM_EXAMPLE_VOLUMES) \
	$(COM_EXAMPLE_WWW_VOLUMES) \
	$(COMPOSE_PROJECT_NAME)_webserver_tmp \
	$(COMPOSE_PROJECT_NAME)_webserver_homedir \
	|| true

# Delete the node_modules dir, in case things get inexplicably screwy and you just feel like you have to nuke something.
# The shell "or" with `true` is so this command never fails.
rm-node-modules:
	docker volume rm $(COMPOSE_PROJECT_NAME)_webserver_homedir_node_modules || true

# Delete generated_artifacts__volume.  This contains all cryptographic material and some channel config material.
# BE REALLY CAREFUL ABOUT RUNNING THIS ONE, BECAUSE IT CONTAINS YOUR ROOT CA CERTS/KEYS.
rm-generated-artifacts:
	docker volume rm $(GENERATED_ARTIFACTS_VOLUME) || true

# Delete the docker image that the webserver uses.  The shell "or" with `true` is so this command never fails.
rm-webserver-env:
	docker rmi $(COMPOSE_PROJECT_NAME)_webserver-env:v0.0 || true

# Delete the containers and images created by the peers that run chaincode.  This will be necessary if the chaincode
# is changed, because new docker images will have to be built with the new chaincode.  If the chaincode has not changed,
# then this is not necessary.  The semicolons are to run the commands sequentially without heeding the exit code.  The
# command `true` is called last so that the make rule is always considered to have succeeded.
rm-chaincode-docker-resources:
	docker rm dev-peer0.org0.example.com-mycc-v0 \
	          dev-peer1.org0.example.com-mycc-v0 \
	          dev-peer0.org1.example.com-mycc-v0 \
	          dev-peer1.org1.example.com-mycc-v0; \
	docker rmi dev-peer0.org0.example.com-mycc-v0 \
	           dev-peer1.org0.example.com-mycc-v0 \
	           dev-peer0.org1.example.com-mycc-v0 \
	           dev-peer1.org1.example.com-mycc-v0; \
	true

# Deletes all non-source resources that this project created that currently still exist.  This should
# reset the project back to a "clean" state.  NOTE: USE WITH CAUTION! This will also wipe out
# generated_artifacts__volume which, unless you backed them up somewhere, if you have configured
# generation of intermediate CAs, then it contains the only copies of your root CAs' keys.
rm-all-generated-resources:
	$(MAKE) down
	$(MAKE) rm-state-volumes rm-node-modules rm-generated-artifacts rm-chaincode-docker-resources
	$(MAKE) rm-webserver-env

# Alias for rm-all-generated-resources.  NOTE: USE WITH CAUTION!
clean: rm-all-generated-resources
