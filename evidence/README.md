# Evidence index

Updated 17 November 2026 (Asia/Calcutta). Nothing in this directory is a live AWS console capture.

| Path | What it is | Label |
| --- | --- | --- |
| `test-results/validation-report.md` | Latest command summary | LOCAL |
| `test-results/validation-report.json` | Full stdout and stderr for that run | LOCAL |
| `reports/discovery-2026-11-17.md` | First environment discovery | DOCUMENTED |
| `task-01/` through `task-06/` | Reserved for future REAL_AWS captures | Empty on purpose |
| `demo-video/` | Reserved for a 2–5 minute recording under 100 MB | Missing |

Rules:

- REAL_AWS means the object was seen in the account.
- LOCAL means the check ran on a machine and did not call AWS.
- SIMULATED means the code imitated an AWS outcome.
- DOCUMENTED means the text describes a design.
- BLOCKED means the check could not be run, and that is not a pass.

Do not add a screenshot from another project. Do not add a file that contains a password, access key, or session token.
