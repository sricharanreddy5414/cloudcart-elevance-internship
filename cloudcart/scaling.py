"""Local Auto Scaling and chaos model.

Results from this module are SIMULATED. They measure the model, not an
EC2 Auto Scaling group.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Instance:
    id: str
    az: str
    purchase: str
    state: str = "pending_wait"
    healthy: bool = True
    schema_ok: bool = False
    warm: bool = False


@dataclass
class ClusterSim:
    instances: dict[str, Instance] = field(default_factory=dict)
    events: list[dict] = field(default_factory=list)
    requests: list[dict] = field(default_factory=list)
    _seq: int = 0

    def launch(self, az: str, purchase: str) -> Instance:
        if purchase not in {"on-demand", "spot"}:
            raise ValueError("purchase must be on-demand or spot")
        self._seq += 1
        instance = Instance(id=f"i-{self._seq}", az=az, purchase=purchase)
        self.instances[instance.id] = instance
        self.events.append({"event": "launch", "id": instance.id, "az": az, "purchase": purchase})
        return instance

    def complete_hook(self, instance_id: str) -> bool:
        instance = self.instances[instance_id]
        if instance.state != "pending_wait":
            raise RuntimeError("lifecycle hook applies only while the instance is pending")
        if not instance.schema_ok or not instance.warm:
            self.events.append({"event": "hook_held", "id": instance.id})
            return False
        instance.state = "in_service"
        self.events.append({"event": "registered", "id": instance.id})
        return True

    def serving(self) -> list[Instance]:
        return [item for item in self.instances.values() if item.state == "in_service" and item.healthy]

    def request(self, latency_ms: int = 0) -> bool:
        targets = self.serving()
        ok = bool(targets) and latency_ms < 5000
        self.requests.append({"ok": ok, "targets": [item.id for item in targets], "latency_ms": latency_ms})
        return ok

    def terminate(self, instance_id: str) -> None:
        instance = self.instances[instance_id]
        instance.state = "terminated"
        instance.healthy = False
        self.events.append({"event": "terminated", "id": instance.id, "az": instance.az})

    def fail_az(self, az: str) -> list[str]:
        removed = []
        for instance in list(self.instances.values()):
            if instance.az == az and instance.state == "in_service":
                self.terminate(instance.id)
                removed.append(instance.id)
        self.events.append({"event": "az_failure_simulated", "az": az, "removed": removed})
        return removed

    def fail_health(self, instance_id: str) -> None:
        self.instances[instance_id].healthy = False
        self.events.append({"event": "health_failed", "id": instance_id})

    def availability(self) -> float | None:
        if not self.requests:
            return None
        return sum(1 for item in self.requests if item["ok"]) / len(self.requests)


def scaling_decision(cpu_percent: float, requests_per_target: float, cpu_target: float = 60, request_target: float = 100) -> str:
    if cpu_percent >= cpu_target or requests_per_target >= request_target:
        return "scale_out"
    if cpu_percent <= cpu_target * 0.5 and requests_per_target <= request_target * 0.5:
        return "scale_in"
    return "hold"


def mixed_capacity(desired: int, on_demand_base: int = 1) -> dict:
    if desired < 1:
        raise ValueError("desired capacity must be at least 1")
    on_demand = min(desired, on_demand_base)
    spot = desired - on_demand
    return {"on_demand": on_demand, "spot": spot, "uses_both": on_demand > 0 and spot > 0}
