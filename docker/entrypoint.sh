#!/bin/bash
set -e

. .venv/bin/activate
fornax-cutouts $@
