app [solution] {
    pf: platform "../platform/main.roc",
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
