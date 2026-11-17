# Security monitoring and event triage lab

**Status: offline analysis implemented with synthetic events. Wazuh/VMware integration not deployed or verified.**

## Scenario
A Windows lab endpoint records multiple failed logons (Windows Security Event ID 4625). Analyze benign synthetic records and flag five or more failed logons for the same host, account and source IP within ten minutes. Event 4624 represents a successful logon and is not counted.

## Architecture
Windows endpoints → (future: Wazuh agent) → (future: Wazuh manager/indexer/dashboard) → analyst triage. Current working component: sample JSONL → Python analyzer → JSON findings. The included events are fabricated, not real host telemetry.

## Run (Python 3.9+, no dependencies)
```bash
python analyze.py
python -m unittest discover -v
```
Expected: seven events processed, one review finding for `lab-win01` / `labuser` / `192.0.2.10`. The address is documentation-only (RFC 5737 TEST-NET-1).

## Investigation workflow
1. Verify event origin and timestamp integrity.
2. Correlate the source IP, target account and host.
3. Check whether a successful logon followed failures.
4. Compare with authorized maintenance or user activity.
5. Escalate only after contextual verification; five failures alone do not prove an attack.

## Future live Wazuh lab
Install a Wazuh manager/indexer/dashboard in an isolated VM environment, onboard a disposable Windows test agent, enable Windows Security event ingestion, generate only authorized benign failed-logon tests, verify events in the dashboard, and capture redacted evidence. Do not represent the synthetic analyzer as a deployed Wazuh detection rule.

## Evidence checklist
- [x] Reproducible synthetic sample events
- [x] Runnable detection script and unit tests
- [ ] Wazuh dashboard screenshot from a live lab
- [ ] Agent registration and ingestion evidence
- [ ] Detection tuning and false-positive analysis from live events
