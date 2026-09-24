TEAM ?= team-alpha
ENV  ?= dev

plan:
	./scripts/apply-team.sh $(TEAM) plan

apply:
	./scripts/apply-team.sh $(TEAM) apply

validate:
	terraform -chdir=./modules/team-resources init -backend=false
	terraform -chdir=./modules/team-resources validate
	terraform fmt -check -recursive

lint:
	tflint --recursive

.PHONY: plan apply validate lint