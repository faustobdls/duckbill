#!/usr/bin/env bash

set -e

echo "Running tests and coverage for \$PWD"

dart test --coverage=coverage
format_coverage --lcov --in=coverage --out=coverage/lcov.info --packages=.dart_tool/package_config.json --report-on=lib
lcov --summary coverage/lcov.info
