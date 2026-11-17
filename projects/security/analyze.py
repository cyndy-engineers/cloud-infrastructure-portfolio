#!/usr/bin/env python3
"""Offline security-event triage demonstration; NOT a Wazuh integration."""
import argparse
import json
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

def analyze(events, threshold=5, minutes=10):
    groups = defaultdict(list)
    for event in events:
        if event.get('event_id') != 4625:
            continue
        time = datetime.fromisoformat(event['timestamp'].replace('Z', '+00:00'))
        groups[(event['host'], event['user'], event['source_ip'])].append(time)
    findings = []
    for (host, user, source), times in sorted(groups.items()):
        times.sort()
        for index, start in enumerate(times):
            window = [t for t in times[index:] if t - start <= timedelta(minutes=minutes)]
            if len(window) >= threshold:
                findings.append({'host': host, 'user': user, 'source_ip': source, 'failed_logons': len(window), 'window_start': start.isoformat(), 'severity': 'review'})
                break
    return findings

def main():
    parser = argparse.ArgumentParser(description='Analyze synthetic Windows sign-in events')
    parser.add_argument('file', nargs='?', default=str(Path(__file__).with_name('events.jsonl')))
    args = parser.parse_args()
    with open(args.file, encoding='utf-8') as source:
        events = [json.loads(line) for line in source if line.strip()]
    print(json.dumps({'events_processed': len(events), 'findings': analyze(events)}, indent=2))

if __name__ == '__main__':
    main()
