app [part1, part2] {
    pf: platform "../platform/main.roc",
}

examplePart1 =
    "the example for part 1"

expect part1 examplePart1 == "the example for part 1" |> Str.toUtf8

part1 : Str -> List U8
part1 = \input ->
    input
    |> Str.toUtf8

examplePart2 =
    "example for part 2"

expect part2 examplePart2 == "2 trap rof elpmaxe" |> Str.toUtf8

part2 = \input ->
    input
    |> Str.toUtf8
    |> List.reverse
