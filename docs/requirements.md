# Requirements

What AutoFlow needs to run:

- Claude Code v2.1.277+
- `jq`
- the GitHub CLI `gh`
- a GitHub repository (one per sub-repo, for a project with sub-repos)

At every session start the plugin's SessionStart hook,
`<autoflow-root>/hooks/ensure-user-config.sh`, tells the operator (`systemMessage`)
of a tool above not found on `PATH` or a `claude` on `PATH` older than the minimum.
It never blocks the session, and a version it cannot read is not reported. It does
not check the GitHub repository, which belongs to each target. The tools and the
minimum it checks are held in `<autoflow-root>/scripts/lib/prerequisites.sh`
([ADR-0041](records/adr/0041-session-start-requirements-notice.md)).

The version it judges is that of the `claude` on the hook's `PATH`, not of the
running Claude Code, which a hook has no documented way to read. When the two are
different installs, a current Claude Code can get the notice and a Claude Code
below the minimum can get none, so no notice does not show the running version
meets the minimum.
