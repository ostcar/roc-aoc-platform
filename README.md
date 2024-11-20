# Roc Platform for Advent of Code

This is a [Roc](https://www.roc-lang.org/)-Platform for Advent of Code.

The puzzle input file has to be next to the roc file with an `.input` extension.
Another input file can be specified by giving a file name. `-` for stdin.

The platform staticly allocates memory on startup. The default is one GiB.
Another amount can be specified with `--memory <BYTES>` or `roc run dayX.roc -- --memory <BYTES>`.

As default, both parts are calculated. By using `--part1` or `--part2` only one
part is calculated.

An roc file can be look like this:

```roc
app [solution] {
    pf: platform "https://github.com/ostcar/roc-aoc-platform/releases/download/v0.0.4/wTZSKRsnoHeTyBzizjkN309WJPSkAFvlq8DUK1ZeCZg.tar.br",
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

```
