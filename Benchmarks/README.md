# Benchmarks

## Running

Run and check results.

```zsh
swift package benchmark
```

## Checking against baselines

Run for a specific Swift version, for example:
```zsh
swift package benchmark baseline check --check-absolute-path Thresholds/5.10/
```

## Updating baselines

Update for a specific Swift version, for example:
```zsh
swift package --allow-writing-to-package-directory benchmark --format metricP90AbsoluteThresholds --path Thresholds/5.10/
```
