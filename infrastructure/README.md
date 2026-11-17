# Infrastructure

No AWS resource has been created. No template is ready to apply.

`terraform/` and `cloudformation/` will hold the templates for an approved step, after the identity check. `scripts/` will hold the matching create and destroy commands for that same step. A script is added in the same session as the approval, not in advance.

Do not run `terraform apply` or `aws cloudformation deploy` against this folder. There is nothing safe to apply yet.
