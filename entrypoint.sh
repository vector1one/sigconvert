#!/bin/sh

cd backend/ && ./launch-backends.sh && cd ..
cd frontend && .venv/bin/python frontend.py
