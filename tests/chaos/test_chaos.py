import unittest

from cloudcart.scaling import ClusterSim, mixed_capacity, scaling_decision


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


if __name__ == "__main__":
    unittest.main()
