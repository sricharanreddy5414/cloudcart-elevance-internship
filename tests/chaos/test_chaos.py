import unittest

from cloudcart.scaling import ClusterSim, mixed_capacity, next_desired, scaling_decision


def ready(cluster: ClusterSim, az: str, purchase: str):
    instance = cluster.launch(az, purchase)
    instance.schema_ok = True
    instance.warm = True
    cluster.complete_hook(instance.id)
    return instance


class ChaosModelTest(unittest.TestCase):
    def test_instance_is_not_registered_before_warmup_and_schema_match(self):
        cluster = ClusterSim()
        blocked = cluster.launch("ap-south-1a", "on-demand")
        self.assertFalse(cluster.request())
        self.assertEqual(cluster.resolve_launch(blocked.id), "ABANDON")
        self.assertEqual(blocked.state, "terminated")
        schema_only = cluster.launch("ap-south-1a", "on-demand")
        schema_only.schema_ok = True
        self.assertEqual(cluster.resolve_launch(schema_only.id), "ABANDON")
        ready = cluster.launch("ap-south-1a", "on-demand")
        ready.schema_ok = True
        ready.warm = True
        self.assertEqual(cluster.resolve_launch(ready.id), "CONTINUE")
        self.assertTrue(cluster.request())

    def test_zone_loss_keeps_the_other_zone_and_total_loss_does_not(self):
        cluster = ClusterSim()
        for zone, purchase in (("ap-south-1a", "on-demand"), ("ap-south-1b", "spot")):
            instance = cluster.launch(zone, purchase)
            instance.schema_ok = True
            instance.warm = True
            cluster.complete_hook(instance.id)
        for _ in range(4):
            self.assertTrue(cluster.request())
        cluster.fail_az("ap-south-1a")
        self.assertTrue(cluster.request())
        cluster.fail_az("ap-south-1b")
        self.assertFalse(cluster.request())
        self.assertLess(cluster.availability(), 1)
        replacement = cluster.launch("ap-south-1b", "on-demand")
        replacement.schema_ok = True
        replacement.warm = True
        cluster.complete_hook(replacement.id)
        self.assertTrue(cluster.request())

    def test_failed_health_and_latency_remove_capacity(self):
        cluster = ClusterSim()
        instance = cluster.launch("ap-south-1a", "on-demand")
        instance.schema_ok = True
        instance.warm = True
        cluster.complete_hook(instance.id)
        cluster.fail_health(instance.id)
        self.assertFalse(cluster.request())
        instance.healthy = True
        self.assertFalse(cluster.request(latency_ms=5000))

    def test_scaling_and_mixed_purchases(self):
        self.assertEqual(scaling_decision(70, 10), "scale_out")
        self.assertEqual(scaling_decision(10, 100), "scale_out")
        self.assertEqual(scaling_decision(40, 40), "hold")
        self.assertEqual(scaling_decision(10, 10), "scale_in")
        both = mixed_capacity(3, on_demand_base=1)
        self.assertEqual(both, {"on_demand": 1, "spot": 2, "uses_both": True})
        self.assertFalse(mixed_capacity(1)["uses_both"])

    def test_spot_interruption_stops_that_instance_only(self):
        cluster = ClusterSim()
        on_demand = ready(cluster, "ap-south-1a", "on-demand")
        spot = ready(cluster, "ap-south-1b", "spot")
        self.assertEqual(cluster.interrupt_spot(spot.id), "draining")
        self.assertNotIn(spot.id, [item.id for item in cluster.serving()])
        self.assertIn(on_demand.id, [item.id for item in cluster.serving()])
        self.assertTrue(cluster.request())
        with self.assertRaises(ValueError):
            cluster.interrupt_spot(on_demand.id)

    def test_launch_timeout_abandons_and_does_not_serve(self):
        cluster = ClusterSim()
        pending = cluster.launch("ap-south-1a", "on-demand")
        self.assertEqual(cluster.expire_launch(pending.id, 100), "PENDING")
        self.assertEqual(cluster.expire_launch(pending.id, 600), "ABANDON")
        self.assertEqual(pending.state, "terminated")
        self.assertFalse(cluster.request())

    def test_scale_in_keeps_the_minimum_and_the_on_demand_base(self):
        cluster = ClusterSim()
        ready(cluster, "ap-south-1a", "on-demand")
        ready(cluster, "ap-south-1a", "spot")
        ready(cluster, "ap-south-1b", "spot")
        removed = cluster.scale_in(minimum=2)
        self.assertEqual(cluster.instances[removed].purchase, "spot")
        self.assertEqual(len(cluster.serving()), 2)
        self.assertIsNone(cluster.scale_in(minimum=2))
        self.assertTrue(any(item.purchase == "on-demand" for item in cluster.serving()))

    def test_load_spike_does_not_serve_from_an_unready_instance(self):
        self.assertEqual(next_desired(2, "scale_out", 2, 4), 3)
        self.assertEqual(next_desired(4, "scale_out", 2, 4), 4)
        self.assertEqual(next_desired(2, "scale_in", 2, 4), 2)
        cluster = ClusterSim()
        ready(cluster, "ap-south-1a", "on-demand")
        added = cluster.launch("ap-south-1b", "spot")
        self.assertNotIn(added.id, [item.id for item in cluster.serving()])
        self.assertTrue(cluster.request())
        added.schema_ok = True
        added.warm = True
        self.assertEqual(cluster.resolve_launch(added.id), "CONTINUE")
        self.assertEqual(len(cluster.serving()), 2)


if __name__ == "__main__":
    unittest.main()
