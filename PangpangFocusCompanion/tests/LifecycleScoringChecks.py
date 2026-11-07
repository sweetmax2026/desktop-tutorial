import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('lifecycle_score', Path(__file__).parents[1] / 'scripts/check-acceptance-lifecycle.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class LifecycleScoringChecks(unittest.TestCase):
    def test_idle_sleep_never_borrows_old_round(self):
        rows = [dict(event='checkpoint',phase='focus',endDate=60,activeSessionID='old',records=2),
                dict(event='NSWorkspaceWillSleepNotification',phase='idle',records=4),
                dict(event='NSWorkspaceDidWakeNotification',phase='idle',records=4)]
        result = module.score(rows, {'records': [{'id':'later'}] * 5})
        self.assertEqual(result['status'], 'NOT_VERIFIED')
        self.assertTrue(result['actualSleepEvent'])

    def rows(self):
        return [dict(event='NSWorkspaceWillSleepNotification',phase='focus',endDate=60,activeSessionID='target',records=2,unixTime=978307210),
                dict(event='NSWorkspaceDidWakeNotification',phase='focus',endDate=60,activeSessionID='target',records=2,unixTime=978307300),
                dict(event='checkpoint',phase='completed',records=3,unixTime=978307302)]

    def test_one_completion_at_original_deadline(self):
        records = [dict(id='target',completed=True,endedAt=60)]
        self.assertEqual(module.score(self.rows(),{'records':records})['status'],'PASS')

    def test_duplicate_and_changed_deadline_fail(self):
        record = dict(id='target',completed=True,endedAt=60)
        self.assertEqual(module.score(self.rows(),{'records':[record,record]})['status'],'FAIL')
        self.assertEqual(module.score(self.rows(),{'records':[dict(record,endedAt=61)]})['status'],'FAIL')

    def test_idle_intervals_do_not_override_matching_active_sleep(self):
        rows = self.rows() + [dict(event='NSWorkspaceWillSleepNotification',phase='idle',records=3,unixTime=978307400)]
        self.assertEqual(module.score(rows,{'records':[dict(id='target',completed=True,endedAt=60),dict(id='later')]})['status'],'PASS')

    def test_pre_deadline_wake_is_not_completion_failure(self):
        rows = self.rows()[:2]
        rows[1]['unixTime'] = 978307230
        result = module.score(rows, {'phase':'focus','activeSessionID':'target','endDate':60,'records':[]})
        self.assertEqual(result['status'],'PASS_BEFORE_DEADLINE')

if __name__ == '__main__':
    unittest.main()
