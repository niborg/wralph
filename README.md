# NITL - Human-In-The-Loop AI Factory

A Ruby-based toolset for automating software development workflows using AI (Claude Code) in a human-in-the-loop pattern. Create GitHub issues, generate implementation plans, execute code changes, and iterate through CI failures automatically.

## Overview

This toolset provides a streamlined workflow for fixing bugs, implementing features, or making code changes by combining AI-powered code generation with human oversight. The process flows from issue creation → plan generation → execution → CI iteration → human review.

## Workflow

```mermaid
flowchart TD
    Start[Create GitHub Issue] --> Init[nitl init]
    Init --> Plan[nitl plan ISSUE_NUMBER]
    Plan --> PlanGen[AI Generates Plan]
    PlanGen --> Review{Human Reviews Plan}
    Review -->|Needs Changes| PlanGen
    Review -->|Approved| Execute[Execute Plan]
    Execute --> Code[AI Makes Code Changes]
    Code --> PR[Create Pull Request]
    PR --> CI[Monitor CI Build]
    CI --> CheckCI{CI Passes?}
    CheckCI -->|No| Fix[AI Analyzes Failures]
    Fix --> Push[Push Fixes]
    Push --> CI
    CheckCI -->|Yes| HumanReview{Human Reviews PR}
    HumanReview -->|Changes Requested| Feedback[nitl feedback ISSUE_NUMBER]
    Feedback --> Changes[AI Makes Changes]
    Changes --> CI
    HumanReview -->|Approved| Cleanup[nitl remove ISSUE_NUMBER]
    Cleanup --> Done[Complete]
```

## Prerequisites

Before using these scripts, ensure you have the following tools installed:

- **[Ruby](https://www.ruby-lang.org/)** `>= 3.0` - Ruby interpreter (use rbenv, rvm, or Homebrew to install)
- **[GitHub CLI](https://cli.github.com/)** (`gh`) - Must be authenticated (`gh auth login`)
- **[Claude Code CLI](https://code.claude.com/)** (`claude`) - For AI-powered code generation
- **[jq](https://stedolan.github.io/jq/)** - JSON processor (install via `brew install jq` on macOS)
- **[curl](https://curl.se/)** - HTTP client (usually pre-installed)
- **[worktrunk](https://github.com/max-sixty/worktrunk)** (`wt`) - Git worktree management tool

## Configuration

Create a `.env` file in the repository root with your CircleCI API token:

```bash
CIRCLE_CI_API_TOKEN=your_token_here
```

The scripts automatically load environment variables from this file. The CircleCI token is required for monitoring build status and fetching failure details.

## Installation

If you're installing NITL (once it's distributed via Homebrew):

```bash
brew install nitl  # When available
```

For development:

1. Ensure you have Ruby 3.0 or higher installed
2. Clone this repository
3. Install dependencies: `bundle install`

## Usage

### 1. Initialize NITL

```bash
nitl init
```

This creates the `.nitl` directory structure needed for plans and configuration.

### 2. Create and Plan an Issue

```bash
nitl plan 123
```

This command:
- Fetches GitHub issue #123
- Uses Claude Code to generate a detailed plan saved to `.nitl/plans/plan_gh_issue_no_123.md`
- Prompts you to review and approve the plan
- Automatically proceeds to execution once approved

The plan includes:
- Analysis of the issue
- Approach to solving it
- Test cases to verify the solution
- Implementation steps
- Potential risks or considerations
- Questions for clarification (if needed)

After plan approval, `nitl plan` automatically:
- Creates a git worktree for branch `issue-123`
- Uses Claude Code to implement the plan
- Commits changes (including the plan file) with a descriptive message
- Pushes the branch and creates a pull request
- Monitors CircleCI build status for the PR
- If CI fails: extracts failure details, uses Claude Code to fix issues, pushes fixes, and iterates (up to 10 retries)
- If CI passes: exits successfully

**Note:** The AI is instructed not to run tests locally, but instead to push a PR and rely on CI.

Failure details are saved to `tmp/issue-{NUMBER}_failure_details_{ITERATION}.txt` for reference.

### 3. Handle PR Review Feedback

When reviewers request changes on a PR:

```bash
nitl feedback 123
```

This command:
- Switches to the worktree for branch `issue-123`
- Prompts you to enter feedback (multi-line input, press Enter 3 times to submit)
- Uses Claude Code to analyze the feedback and make changes
- Pushes the changes and monitors CI again (with automatic retries if CI fails)

### 4. Clean Up (Optional)

To delete a branch and its worktree after completion:

```bash
nitl remove 123
```

This removes:
- Local branch `issue-123`
- Remote branch `issue-123`
- Associated worktree

## Commands Overview

| Command | Purpose |
|---------|---------|
| `nitl init` | Initialize NITL in the current repository |
| `nitl plan <issue_number>` | Generate plan and execute it (creates PR, monitors CI) |
| `nitl feedback <issue_number>` | Handle PR review feedback and iterate |
| `nitl remove <issue_number>` | Clean up branches and worktrees |

## Directory Structure

The tool creates and manages the following:

```
.
├── .env                          # Environment variables (you create this)
├── .nitl/                        # NITL configuration directory (created by `nitl init`)
│   └── plans/                    # Generated plans
│       └── plan_gh_issue_no_123.md  # Example plan file
├── tmp/                          # CI failure details (created automatically)
│   └── issue-123_failure_details_1_1.txt
└── [worktree directories]        # Managed by worktrunk
```

## Key Features

- **Worktree Isolation**: Each issue gets its own git worktree via worktrunk, keeping your main working directory clean
- **Automatic CI Integration**: Monitors CircleCI builds, extracts failure details, and iteratively fixes issues
- **Human Oversight**: Plans require approval before execution, and PRs can be reviewed before merging
- **Failure Recovery**: Automatically retries up to 10 times to fix CI failures
- **Branch Management**: Automatic branch creation, PR creation, and cleanup utilities
- **Plan Persistence**: All plans are saved for reference and context during iterations

## Workflow Tips

1. **Initialize First**: Always run `nitl init` before using other commands
2. **Start Clean**: Ensure you don't have uncommitted changes before running `nitl plan` (or commit/stash them first)
3. **Review Plans Carefully**: The plan review step is your opportunity to catch issues before code changes
4. **Monitor Output**: Commands provide colored output (ℹ info, ✓ success, ⚠ warning, ✗ error) to track progress
5. **PR Linking**: PRs automatically reference the GitHub issue (e.g., "Fixes #123") for proper linking
6. **CI Timeout**: CI monitoring waits up to 1 hour for builds to complete
7. **Max Retries**: If CI fails more than 10 times, the command exits and requires manual intervention

## Example Session

```bash
# 1. Initialize NITL in your repository
nitl init

# 2. Create a GitHub issue describing the bug/feature

# 3. Generate and execute plan:
nitl plan 456

# Review the generated plan at .nitl/plans/plan_gh_issue_no_456.md
# Answer any questions Claude asked, then approve

# 4. Command automatically:
#    - Executes the plan
#    - Creates PR #789
#    - Monitors CI
#    - Fixes failures if needed

# 5. Review the PR on GitHub

# 6. If changes are needed:
nitl feedback 456
# Enter your feedback, press Enter 3 times

# 7. After merging, clean up:
nitl remove 456
```

## Error Handling

The tool includes error handling for common scenarios:
- NITL not initialized (must run `nitl init` first)
- Missing GitHub authentication
- Uncommitted changes (with warning)
- Duplicate branches (must delete first)
- Missing plan files
- CI timeout or max retries exceeded
- Missing required tools

All errors provide clear messages about what went wrong and how to resolve the issue.

## Development

### Requirements

- Ruby 3.0 or higher (specified in `.ruby-version` and `Gemfile`)
- Development dependencies installed via `bundle install`

### Running Tests

```bash
bundle exec rspec
```

Tests are located in the `spec/` directory and are excluded from distribution packages.
