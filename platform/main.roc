platform "aoc"
    requires {} { solution : [Part1, Part2] -> List U8 }
    exposes []
    packages {}
    imports []
    provides [solutionForHost]

solutionForHost : [Part1, Part2] -> List U8
solutionForHost = \part ->
    solution part
