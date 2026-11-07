"""Score actual OS sleep evidence against the isolated test app's own snapshot."""
import json, plistlib, subprocess, sys
from pathlib import Path

def score(rows, snapshot):
    starts = [i for i, row in enumerate(rows) if row['event'] == 'recorderStarted']
    if starts:
        rows = rows[starts[-1]:]
    sleeps = [i for i, row in enumerate(rows) if 'WillSleep' in row['event']]
    result = {
        'status': 'NOT_VERIFIED', 'actualSleepEvent': bool(sleeps),
        'actualWakeEvent': any('DidWake' in row['event'] for row in rows),
        'screenLockedEvent': any(row['event'] == 'com.apple.screenIsLocked' for row in rows),
        'screenUnlockedEvent': any(row['event'] == 'com.apple.screenIsUnlocked' for row in rows),
    }
    # Never borrow an earlier focus round if the app was idle at sleep time.
    active_sleeps = [i for i in sleeps if rows[i]['phase'] == 'focus'
                     and rows[i].get('endDate') is not None and rows[i].get('activeSessionID')]
    if not active_sleeps:
        result['reason'] = 'No active focus at any recorded sleep event' if sleeps else 'No actual sleep event'
        return result
    sleep_index = active_sleeps[-1]
    before = rows[sleep_index]
    tail = rows[sleep_index + 1:]
    wake = next((row for row in tail if 'DidWake' in row['event']), None)
    if wake is None:
        result['reason'] = 'No wake event after the active focus sleep event'
        return result
    result.update(wakeAfterDeadline=wake['unixTime'] >= before['endDate'] + 978307200,
                  sleepToWakeSeconds=round(wake['unixTime'] - before['unixTime'], 2),
                  recordsBefore=before['records'], recordsAfter=len(snapshot.get('records', [])))
    matching = [record for record in snapshot.get('records', []) if record['id'] == before['activeSessionID']]
    if not matching and snapshot.get('phase') == 'focus' and not result['wakeAfterDeadline']:
        intact = snapshot.get('activeSessionID') == before['activeSessionID'] and snapshot.get('endDate') == before['endDate']
        result.update(status='PASS_BEFORE_DEADLINE' if intact else 'FAIL', activeDeadlinePreserved=intact)
        return result
    passed = len(matching) == 1 and matching[0].get('completed') is True and matching[0]['endedAt'] == before['endDate']
    # Extra later user-started rounds are unrelated; judge the matching session
    # and the first completion checkpoint after wake rather than global totals.
    first_completion = next((row for row in tail if row['unixTime'] >= wake['unixTime'] and row['phase'] == 'completed'), None)
    if first_completion:
        passed = passed and first_completion['records'] == before['records'] + 1
    if not matching and not result['wakeAfterDeadline']:
        result['reason'] = 'Awaiting completion/checkpoint for this round'
        return result
    result.update(status='PASS' if passed else 'FAIL', oneMatchingCompletionAtOriginalDeadline=passed)
    return result


def main():
    path = Path('/private/tmp/pang-acceptance-lifecycle.jsonl')
    rows = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    values = plistlib.loads(subprocess.check_output(['defaults', 'export', 'pangpang.release.acceptance.v1', '-']))
    result = score(rows, json.loads(values['pangpang.pomodoro.snapshot']))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if len(sys.argv) > 1:
        Path(sys.argv[1]).write_text(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['status'].startswith('PASS') else 2 if result['status'] == 'NOT_VERIFIED' else 1


if __name__ == '__main__':
    sys.exit(main())
