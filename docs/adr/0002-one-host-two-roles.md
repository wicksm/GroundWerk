# 2. One Host, run as the API or the jobs

Status: Accepted

## Context

The Hangfire jobs call the same handlers as the API's endpoints, in process, so a write gets the same validation and rules whichever way it comes in. If every API process also ran the jobs, each scale-out would add job workers, the processing rate would change with traffic, and jobs would compete with requests for CPU, threads and SQL connections.

## Decision

GroundWerk.Host is one ASP.NET Core app, built into one image from one Dockerfile and deployed twice. Its Role setting picks what a process runs: api serves the endpoints and the Hangfire dashboard and only enqueues jobs, and jobs runs the Hangfire servers at a fixed replica count. appsettings.json sets Role to api, each deployment sets its own, and any other value stops the Host at startup with an error naming both.

## Alternatives considered

- Hangfire's servers in every API process, which ties the job rate to the API's scaling.
- A separate jobs app with its own image, which duplicates the startup code and lets its configuration drift from the API's.

## Consequences

- One build and one image, deployed twice with different Role values and replica counts.
- Startup code branches on Role, and each role keeps a health endpoint for its probes.
