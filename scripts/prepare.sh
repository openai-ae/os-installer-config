#!/usr/bin/env bash

# Prepare pacman
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -Syy
