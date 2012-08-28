# Contradictionary

A two-player turn-based board game inspired by Chinese Checkers and Scrabble.

## Game Elements

Two human _players_.

The _game board_ consists of a 2-D grid of _cells_. Each cell may be unoccupied or
occupied by a single _letter tile_.

A letter tile consists of a _letter_ in (A-Z) and has an associated _point
value_ (e.g. a 'Z' is worth 10 points).  A letter tile is owned by exactly one
player.

Each player is assigned a unique _start cell_ which is one of the 4 corners of
the board. The first word formed by each player must contain a letter tile 
placed on the player's start cell.

Each player has an implicit _end cell_ which is the cell on the corner of the
board opposite the player's start cell.

A _bag_ of letter tiles following a particular frequency distribution -- we
follow what other Scrabble clones do here to give some familiarity to players.

Each player has a _rack_ of 7 random letter tiles visible to only them. 

## Gameplay

Each player takes a turn until one of the game over conditions are met.

On the first turn, each player forms a word by placing letter tiles on the board.
One letter tile must be placed atop the player's start cell.

On subsequent turns, letters may be placed adjacent to any other letter tile
as long as there is at least one word formed by using one or more letter tiles
placed in a previous turn by either player.

## Scoring

Points are awarded to each player for each word formed in a given turn. The
points awarded is equal to the sum of the value of each word formed. Word values
are equal to the sum of the values of the letters that comprise the word. Cell
multipliers affect the point value of an individual letter or word. Such
multipliers include a letter doubler (2L), letter tripler (3L), word doubler
(2W), and word tripler (3W).  Multipliers only have an affect the first time
they become relevant. For example, if a player forms a word off a letter that
was played earlier in the game and resides atop a letter tripler, that player
gets no extra points.

## Game Over Conditions

The game ends when any of the following conditions are met:

1. a path from the start cell to the end cell can be followed by traversing
   words formed by one of the players and that same player has more points than
   his opponent;
2. a player resigns;
3. a player fails to act after some reasonable amount of time;
4. both players pass their turn two times consecutively.

Should a path be found from a player's start cell to the player's end cell by
traversing words formed by the player but the player has fewer points than his
opponent, the player must continue to form additional words (if possible).

## Other Elements

A player may place a single _bomb_ per turn anywhere on the board. Should the
opponent form a word atop a bomb, the word is destroyed, the player loses the
letters forming the word, the player's bomb is destroyed, and opponent's turn
ends.

A letter tile placed atop a bomb owned by the owner of the bomb causes the bomb
to be removed from the board and returned to the player's inventory of bombs.

A player may place a single _defuser_ per turn anywhere on the board. Should his
opponent place a bomb on a cell containing a defuser, the bomb is defused and is
added to the player's inventory.

## Scrabble Elements

The gameplay elements related to Scrabble are:

- each player has a "rack" of letter tiles picked at random from a distribution
  of tiles (the "bag");

- players form words by placing letter(s) from their rack onto the board;

- the ENABLE1 dictionary (with the same edits as made by "Words with Friends")
  is used as the source word-list or dictionary;

- each player takes a turn by forming words on the board, passing, exchanging
  one or more letter tiles with new tiles from the bag, or resigns;

- letter tiles from a player's rack used in a turn are replenished by picking
  randomly from the bag;

- racks may be "shuffled";

- one or more letter tiles may be exchanged for random tiles picked from the
  bag;

- letter tiles have point values;

- scoring follows the same algorithm with respect to letter and word values,
  cell multipliers, etc.;

Elements that are different from Scrabble include:

- the game-over condition

## Chinese Checkers Elements

Starting on one side of the board and trying to reach the opposite side.

In Contradictionary, pieces (tiles) are not jumped in order to move.

## iOS Version

Targets iPhone, iPod, and iPad.

The game board and letter tiles are rendered in an isometric style.


