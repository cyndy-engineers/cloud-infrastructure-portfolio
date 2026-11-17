import unittest
from analyze import analyze

class AnalyzeTests(unittest.TestCase):
    def test_threshold(self):
        events = [{'timestamp': f'2026-11-17T10:0{i}:00Z', 'host': 'lab', 'user': 'test', 'source_ip': '192.0.2.10', 'event_id': 4625} for i in range(5)]
        self.assertEqual(len(analyze(events)), 1)
        self.assertEqual(len(analyze(events[:4])), 0)
    def test_other_events_ignored(self):
        events = [{'timestamp': '2026-11-17T10:00:00Z', 'host': 'lab', 'user': 'test', 'source_ip': '192.0.2.10', 'event_id': 4624}] * 5
        self.assertEqual(analyze(events), [])

if __name__ == '__main__':
    unittest.main()
