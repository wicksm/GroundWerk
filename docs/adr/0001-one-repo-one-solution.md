# 1. One repo and one solution for everything GroundWerk ships

Status: Accepted

## Context

The API, the jobs, the ingestors, the poller and the outbox relay share one database. Changing a table they share touches the SQL project, the EF Core mapping, the code that reads or writes it, and their tests.

## Decision

One repo holds every app the team ships, with the SQL project, the team's infrastructure code and its pipelines, in one solution, GroundWerk.slnx. Code that only these apps share is a project reference, never a package. Only what many teams consume by version gets a repo of its own: the pipeline templates, the company-wide packages and the Terraform modules. Path filters keep each app building and deploying on its own.

## Alternative considered

A repo per deployable, with shared code published as packages. Changing a shared column then takes a coordinated PR in each repo, plus a package release, merged in the right order.

## Consequences

- One PR changes a table, its mapping, the code that uses it and the tests together.
- Each pipeline needs path filters, or every change builds and deploys everything.
- The paths are a contract: path filters, AGENTS.md and the AI developer's skill depend on them, so moving a project means changing all three in the same PR.
