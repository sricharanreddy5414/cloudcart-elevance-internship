# Task 3 — Auto Scaling, mixed instances, and chaos tests

Status: **Not started.** No Auto Scaling group exists.

## Objective

Add and remove EverShop capacity automatically, including Spot and On-Demand, and show that the store keeps answering while an instance is removed and while one Availability Zone is taken out of service.

## Requirements

1. Auto Scaling groups.
2. On-Demand and Spot together.
3. Lifecycle hooks.
4. Warm-up and database migration activity before the instance registers with the target group.
5. Scaling on ALB request count and on CPU utilization.
6. Terminate instances under a controlled load.
7. Simulate an Availability Zone failure.
8. Service continuity and no downtime under the conditions that were defined before the test.

## Design notes

The group runs the ECS container instances in private subnets in at least two Availability Zones. The mixed-instances policy sets a base of On-Demand capacity and a percentage of Spot above that. Spot interruption is a normal event; the hook and the load balancer have to tolerate it.

The launch lifecycle hook leaves the instance in `Pending:Wait`. A bootstrap script waits until the schema version in the database matches the image, then warms the local process, then completes the hook. Only after that may tasks be placed and registered with the target group.

The schema change itself runs once, from the pipeline, with a lock. If every new instance ran a migration, two instances launching together could apply the same change at once. The hook still performs a migration activity: it checks the version and refuses to continue when the version is behind. That is the safe reading of the requirement. Decision D-008 records it.

Scaling uses target tracking on `ALBRequestCountPerTarget` and on CPU. Scale-in protection during a deploy avoids removing the instance that is mid-test.

## What "no downtime" will mean in the test

Before the test starts, write the conditions down:

- Minimum healthy tasks.
- Load-generator URL and rate.
- Success criterion: the generator records no failed storefront response during the instance termination, and during the removal of one zone's instances, outside the requests already in flight when a target was drained.

Connection draining on the target group is part of the setup. A result that shows errors will be reported as errors.

An Availability Zone failure is simulated by terminating the group's instances in that zone, or by temporarily removing that subnet, while the other zone remains. A student account cannot power off the zone itself. The report will use the words "simulated Availability Zone removal."

## Evidence to collect later

- Auto Scaling group, mixed-instances policy, and hook configuration.
- CloudWatch alarms and scaling policies for both metrics.
- Load-test output with timestamps.
- Termination test and zone-removal test, with the load-test result beside them.
- A short note on what recovered, and how long a new instance took to pass the hook.

## Cost

Every instance hour and every gigabyte of cross-AZ load-test traffic can bill. Spot is discounted, not free. The test window is short, and the group is scaled to zero or deleted afterward unless you approve leaving it.

## Not done

No group, no policy, no load test, no chaos test.
