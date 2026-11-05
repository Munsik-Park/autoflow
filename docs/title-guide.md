# Issue & PR Title Guide

Enclose the common prefix in square brackets, and write the rest of the description freely.

## Format

```
[type · epic-slice · #N]  free description    ← epic sub-issue PR
[type · epic-slice]       free description    ← epic sub-issue (number not yet known when the issue is created)
[type · #N]               free description    ← standalone issue / epic tracker / standalone issue PR
```

| Item | Description |
|------|------|
| `type` | `feat` / `fix` / `chore` / `docs` — see the table below |
| `epic-slice` | Epic number and slice code (`#73-S3f`, `#72-S5a`, etc.). Used only for epic sub-issues |
| `#N` | GitHub issue number. Optional in an issue title, recommended in a PR title |
| Free description | No limit on length or language |

## type values

| type | When |
|------|------|
| `feat` | New feature implementation |
| `fix` | Bug fix |
| `chore` | Configuration, infrastructure, automation |
| `docs` | Documentation-only change |

## Examples

### Issue titles

```
[feat · #73-S3f]  Usage history tab frontend — period filter + search
[feat · #72-S5a]  Member management table frontend
[feat · #224]     Enterprise member activity audit log implementation
[fix  · #200]     YouTube subtitle fetch failure
[chore · #43]     PAT rotation documentation
```

### PR titles

```
[feat · #73-S3f · #231]  Usage history tab frontend — period filter + search
[feat · #72-S5a · #217]  Member management table frontend
[feat · #224]             Enterprise member activity audit log
[fix  · #200]             YouTube subtitle fetch failure
[chore · #43]             PAT rotation documentation
```

## Prefix composition principle

`epic-slice` and `#N` have different roles.

| Reference | Meaning | Issue | PR |
|------|------|------|----|
| `epic-slice` (`#73-S3f`) | Which slice of which Epic it is | ✅ | ✅ |
| `#N` (issue number) | Which GitHub issue it closes | Optional | Recommended |

When it is not an epic sub-issue (a standalone issue, an epic tracker), use only `#N`, without `epic-slice`.
