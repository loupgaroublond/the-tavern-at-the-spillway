# Pipeline Dashboard

Generate and display the pipeline dashboard.

## Steps

1. Run the dashboard script to parse all active pipeline docs:

```bash
./scripts/pipeline/dashboard.sh --markdown
```

2. Read the generated dashboard for display:

Read `docs/pipeline/dashboard.md` and display the full content to the user.

3. If there are pipelines that need attention, summarize them briefly:
   - How many pipelines need human input (gate pending, not blocked)
   - How many are actively running (assigned agent)
   - How many are blocked on other pipelines
   - Any verification reports ready for review

4. If asked to update the dashboard without showing it, just run the script silently.
