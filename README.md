# AutoFlow

AutoFlow takes a development request, given as a GitHub issue, through the steps of development. Each step is a module. A coordination session builds a workflow that fits the issue from the modules, runs each module in a work session, judges what it leaves and connects it to the next module, up to pull requests ready for your decision.

Because a step is a module, a step can be replaced. A module you make yourself is listed beside the default modules, and one with a default module's name is used in its place. The workflow then fits your repository and your way of working.

## The three repositories

AutoFlow is three repositories used together.

| Repository | Place |
|---|---|
| [autoflow-module](https://github.com/Munsik-Park/autoflow-module) | The modules. Each is a folder holding one `SKILL.md` that defines a step, such as analysis, design, build and review. It also holds the skill that makes a user module. |
| [autoflow-coordinator](https://github.com/Munsik-Park/autoflow-coordinator) | The coordination session and its tools. It assembles modules into a workflow, opens work sessions and judges their results. |
| [autoflow-ide](https://github.com/Munsik-Park/Autoflow-ide) | The screen over the coordinator: issues, runs and sessions in one terminal UI. |

## How to use them

A person or an AI session setting AutoFlow up reads the README of each repository in this order.

1. **autoflow-coordinator**: its requirements, install steps, workspaces and first run. The install steps include cloning autoflow-module.
2. **autoflow-ide**: how to start the IDE over the coordinator clone.
3. **autoflow-module**: the list of modules, and how to make a user module.

## Changes

Which versions of the three repositories go together, and what changed between versions, are in [CHANGELOG.md](CHANGELOG.md).
