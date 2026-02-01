# Implementation Iterative Terraform with Automation

The intent behind this module is to empower teams to be able to build
standardized but overrides infrastructure and keep their configs close to
their code, while permitting an infrastructure team to manage defaults
in a central location. This enables an infrastructure to have a set of
recommendations that can be used by default without the requirement to specify
values in every config but gives product teams the freedom to build cloud
resources that match their specific needs.

As such, it is suggested that Github Actions be deployed that will
automatically generate pull requests or Action runs in the repositories that
host the Terraform projects. This allows the Terraform projects themselves to
not be updated but instead just the configuration YAML files. This works best
with a solution like running Terraform in Github Actions vs. Atlantis, which
requires a qualifying file modification and related commit to be made into
the repository.
