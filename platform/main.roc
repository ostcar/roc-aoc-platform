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
    when r is
        Ok v -> Ok v
        Err ThisLineIsNecessary -> Err (Inspect.toStr ThisLineIsNecessary) # https://github.com/roc-lang/roc/issues/7289
        Err err -> Err (Inspect.toStr err)
