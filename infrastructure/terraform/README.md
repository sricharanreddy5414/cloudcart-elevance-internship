# Terraform

Empty on purpose.

The first templates will be the network and the database, or the image bucket, depending on which one you approve. Each directory will have a `terraform validate` result saved under `evidence/` before any apply. Remote state and a real backend come with the first approved apply, so state is not stored in git.
