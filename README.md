# HOW TO CODE IN HUR

# GIT
git clone git@github.com:PopePiusXIII/AlienInvasion.git

cd AlienInvasion

optional commands

git pull #syncing to github.com

git checkout -b <branch name> #Create a new branch

git checkout <branch name> #Checkout existing

git status #shows what files you changed

git add <file> #add file to be commited

git add --all #add all files that are changed

git commit -m "my message" #how you commit

git push # how you push to github.com for others to see


# Install

from repository root

wally install

# Type Hinting
luau sucks and isnt statically typed. We use a linter to statically type
You must run ./tools/regenerate_sourcemaps.sh
if you create a new file in the default.project.json

# VsCode
from gitbash and repository root

code AlienInvasion.code-workspace

# Structure

### Common
### Lobby
### Match
### Root

Common is something any experience in game can use. Match is when fighting a horde. Lobby is when you join the game but havent done matchmaking. Root is just so you can see everything as if it were a native directory

# Rojo
Match, Lobby, and Common all have a default.project.json
Depending which experience you are developing you must do a 

```rojo serve default.project.json```

From the appropiate directory

ie root/src/places_match or root/src/places_lobby

from there go to roblox studio and go to rojo plugin and hit connect



