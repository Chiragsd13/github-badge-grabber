# GitHub Badge Grabber

Automatically earn every earnable GitHub Achievement badge in a single command. Creates a temp repo, triggers all badges, then deletes it — no trace left on your profile.

## Badges You Get

| Badge | How |
|---|---|
| Quickdraw | Opens and closes an issue instantly |
| Pull Shark | Merges 2 pull requests |
| YOLO | Merges without a code review |
| Pair Extraordinaire | Co-authored commit with [@Chiragsd13](https://github.com/Chiragsd13) |

## Requirements

- [gh CLI](https://cli.github.com) installed
- Authenticated: `gh auth login`

## Run

```bash
bash <(curl -s https://raw.githubusercontent.com/Chiragsd13/github-badge-grabber/master/github-badge-grabber.sh)
```

Or clone and run:

```bash
git clone https://github.com/Chiragsd13/github-badge-grabber
bash github-badge-grabber/github-badge-grabber.sh
```

## What Happens

1. Verifies you are logged in via gh CLI
2. Creates a temporary public repo
3. Triggers Quickdraw, Pull Shark, YOLO, and Pair Extraordinaire
4. Deletes the temp repo automatically
5. Badges appear on your profile within 24-48h

## Badges Not Included

| Badge | Why | How to Get |
|---|---|---|
| Galaxy Brain | Requires someone to accept your Discussion answer | Answer questions in public repo Discussions |
| Public Sponsor | Requires payment | Sponsor any dev for min $1/month |
| Starstruck | Requires 16 stars on your repo | Build something useful and share it |

## Credits

Built by [@Chiragsd13](https://github.com/Chiragsd13)