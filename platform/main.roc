platform "aoc"
    requires {} { part1 : Str -> List U8, part2 : Str -> List U8 }
    exposes []
    packages {}
    imports []
    provides [part1ForHost, part2ForHost]

part1ForHost : Str -> List U8
part1ForHost = \input ->
    part1 input

part2ForHost : Str -> List U8
part2ForHost = \input ->
    part2 input
