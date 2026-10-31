# Requirements

What AutoFlow needs to run:

- Claude Code v2.1.277+
- `jq`
- the GitHub CLI `gh`
- a GitHub repository (one per sub-repo, for a project with sub-repos)

At every session start the plugin's SessionStart hook,
`<autoflow-root>/hooks/ensure-user-config.sh`, tells the operator (`systemMessage`)
of a tool above not found on `PATH` or a Claude Code older than the minimum. It
never blocks the session, and a version it cannot read is not reported. It does
not check the GitHub repository, which belongs to each target. The tools and the
minimum it checks are held in `<autoflow-root>/scripts/lib/prerequisites.sh`
([ADR-0041](records/adr/0041-session-start-requirements-notice.md)).
