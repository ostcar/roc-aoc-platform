platform "aoc"
    requires {} { part1 : Str -> Result Str _, part2 : Str -> Result Str _ }
    exposes []
    packages {}
    imports []
    provides [part1ForHost, part2ForHost]

part1ForHost : Str -> Result Str Str
part1ForHost = \input ->
    part1 input
    |> errToStr

part2ForHost : Str -> Result Str Str
part2ForHost = \input ->
    part2 input
    |> errToStr

errToStr : Result Str _ -> Result Str Str
errToStr = \r ->
    r |> Result.mapErr Inspect.toStr
