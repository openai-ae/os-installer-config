#!/usr/bin/env bash

# Copy overlay to new root
for f in "${osidir}/overlay/"*; do
    sudo cp -rv "$f" "$workdir/" || quit_on_err 'Failed to copy overlay'
done
