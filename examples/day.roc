app [part1, part2] {
    pf: platform "../platform/main.roc",
}

examplePart1 =
    "the example for part 1"

expect part1 examplePart1 == Ok "the example for part 1"

part1 = \input ->
    input
    |> Ok

examplePart2 =
    "example for part 2"

expect part2 examplePart2 == Ok "2 trap rof elpmaxe"

part2 = \input ->
    input
    |> Str.toUtf8
    |> List.reverse
    |> Str.fromUtf8
