# Evidence rules

Every file under `evidence/` is something that actually happened. If a test has not been run, the folder contains a short note and no screenshot.

## Labels

Use these words in the filename or in the first line of the note:

| Label | Meaning |
| --- | --- |
| A-local | Ran on the Windows Docker host or in a unit test. |
| B-simulated | Exercised the behavior without the AWS service. |
| C-deployed | The AWS resource existed. A console or CLI describe is attached. |
| D-verified | A live check matched the requirement: a header, a query result, a metric, or a failed request that should fail. |

A file may be C and D together. A file that is B cannot also be D.

## Capture

- Prefer CLI text saved to a file, plus a screenshot when the console is the thing being proven.
- Mask account ids if you want. Do not mask the fact that matters, such as `PubliclyAccessible: false` or a certificate status of `ISSUED`.
- No access keys, secret keys, session tokens, passwords, or connection strings in the capture. An IAM authentication token is a secret; show that a connection succeeded, and do not paste the token.
- Record the time in Asia/Calcutta and the command that produced the output.
- Record failures. A failed command and the fix are part of the internship record.

## What is not evidence

- A diagram.
- A template that was not applied.
- A stock screenshot from documentation.
- A metric that was typed in by hand.
- A statement that a deployment was blue/green, unless the capture shows the traffic shift and the rollback.

## Demo video

The video is 2–5 minutes, MP4, WebM, or MOV, and at most 100 MB. It is recorded after the checklist is otherwise complete. It shows the running store and the evidence that exists. It does not show secrets, root credentials, or a flow that was only simulated while the narration calls it live AWS.
