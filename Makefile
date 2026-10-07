.PHONY: fmt validate

fmt:
	terraform fmt -recursive

validate:
	terraform fmt -check -recursive
	python3 -m json.tool policies/ci-pipeline.json >/dev/null
	terraform -chdir=bootstrap/remote-state init -backend=false -input=false
	terraform -chdir=bootstrap/remote-state validate
	terraform -chdir=environments/ec2 init -backend=false -input=false
	terraform -chdir=environments/ec2 validate
	terraform -chdir=environments/iam init -backend=false -input=false
	terraform -chdir=environments/iam validate
