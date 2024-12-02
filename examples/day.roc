app [part1, part2] {
    pf: platform "../platform/main.roc",
}

examplePart1 =
    """
    the example for
    part 1
    """

expect
    got = part1 examplePart1
    expected = Ok "the example for part 1 fail"
    got == expected

part1 = \input ->
    input
    |> Str.replaceEach "\n" " "
    |> Ok

examplePart2 =
    """
    example for
    part 2
    """

expect
    got = part2 examplePart2
    expected = Ok "2 trap rof elpmaxe"
    got == expected

part2 = \input ->
    input
    |> Str.replaceEach "\n" " "
    |> Str.toUtf8
    |> List.reverse
    |> Str.fromUtf8
