# Design decisions

## Why separate state files and not workspaces?
Tried workspaces first mentally — rejected it. If one team's backend 
config breaks, workspaces drag everyone down. Separate S3 keys mean 
one team's mess stays their mess.

## Why YAML for team config and not HCL?
Teams shouldn't need to know Terraform. YAML is readable for anyone.
Platform team owns the module, product teams own their YAML. Clear boundary.

## Why explicit visibility on every bucket?
Had a situation at Nord where someone assumed a bucket default. 
Never again. Force the declaration, catch it at plan time.


## TODO
- Add manual approval gate before destroy in CI
- Add S3 lifecycle policies for cost management


## AI usage
Used Claude to help scaffold the initial module structure and CI workflow. 
Reviewed and understood every line before committing. README, DECISIONS.md 
and the human-touch changes were written by me.