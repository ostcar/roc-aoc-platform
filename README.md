# Roc Platform for Advent of Code

This is a [Roc](https://www.roc-lang.org/)-Platform for Advent of Code.

The platform staticly allocates memory on startup. The default is one GiB.
Another amount can be specified with `--memory <BYTES>` or `roc run dayX.roc --
--memory <BYTES>`.

As default, both parts are calculated. By using `--part1` or `--part2` only one
part is calculated.

An roc file can be look like this:

```roc
app [solution] {
    pf: platform "https://github.com/ostcar/roc-aoc-platform/releases/download/v0.0.3/PQF9VFBtjSDsC525Ma2dXjLcndTmjQHcFYFMkJS6oEI.tar.br",
}

import "day.input" as puzzleInput : List U8

solution = \part ->
    when part is
        Part1 -> part1 puzzleInput
        Part2 -> part2 puzzleInput

examplePart1 =
    "the example for part 1"
    |> Str.toUtf8

expect part1 examplePart1 == "the example for part 1" |> Str.toUtf8

part1 : List U8 -> List U8
part1 = \input ->
    input

examplePart2 =
    "example for part 2"
    |> Str.toUtf8

expect part2 examplePart2 == "2 trap rof elpmaxe" |> Str.toUtf8

part2 = \input ->
    input
    |> List.reverse
```
