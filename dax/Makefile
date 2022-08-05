.PHONY: all
CURRENT_STAGE := "$(notdir $(shell pwd))"
ENV_VAR_FILE := "./environments/${ENV}/terraform.tfvars"
BACKEND_CONF := "./environments/${ENV}/backend.conf"
APP_NAME = "dax-cache"

all: init plan apply 

init:
	@echo "Removing cached terraform modules."
	@rm -Rf .terraform/modules
	@echo "Initialiasing terraform for ** ${APP_NAME} ** ${ENV} environment."
	@terraform init -reconfigure -backend-config=${BACKEND_CONF} -no-color
	@echo "Validating terraform code."
	@terraform validate -no-color

plan:
	@echo "Running a terraform plan on ** ${APP_NAME} ** ${ENV} environment."
	@terraform plan -parallelism=30 -refresh=true -out=plan.out -var-file=terraform.tfvars -var-file=${ENV_VAR_FILE}

apply:
	@echo "Deploying the infrastructure on ** ${APP_NAME} ** ${ENV} environment."
	@terraform apply -no-color -auto-approve -var-file=terraform.tfvars -var-file=${ENV_VAR_FILE}

show:
	@echo "Running show on tf output"
	@terraform show -no-color plan.out

destroy:
	@echo "Destroying the deployment on ** ${APP_NAME} ** ${ENV} environment."
	@terraform destroy -no-color -auto-approve -var-file=terraform.tfvars -var-file=${ENV_VAR_FILE}
