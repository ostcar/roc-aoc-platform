# Roc Platform for Advent of Code

This is a [Roc](https://www.roc-lang.org/)-Platform for Advent of Code.

It can be used like this:

```roc
app [solution] {
    pf: platform "https://github.com/ostcar/roc-aoc-platform/releases/download/v0.0.1/neSojGToSZSAr3hb3DAgXe2sQZR4RhMKEErdh1PJVi4.tar.br",
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
