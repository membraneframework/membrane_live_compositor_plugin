#!/bin/bash

vc_version="v0.1.0-rc.1"

mkdir -p video_compositor_app

linux_x86_64_url="https://github.com/membraneframework/video_compositor/releases/download/${vc_version}/video_compositor_linux_x86_64.tar.gz"
darwin_x86_64_url="https://github.com/membraneframework/video_compositor/releases/download/${vc_version}/video_compositor_darwin_x86_64.tar.gz"
darwin_aarch64_url="https://github.com/membraneframework/video_compositor/releases/download/${vc_version}/video_compositor_darwin_aarch64.tar.gz"

linux_x86_64_path="./video_compositor_app/linux_x86_64"
darwin_x86_64_path="./video_compositor_app/darwin_x86_64"
darwin_aarch64_path="./video_compositor_app/darwin_aarch64"

mkdir -p $linux_x86_64_path
mkdir -p $darwin_x86_64_path
mkdir -p $darwin_aarch64_path

wget $linux_x86_64_url -O - | tar -xvz -C $linux_x86_64_path
wget $darwin_x86_64_url -O - | tar -xvz -C $darwin_x86_64_path
wget $darwin_aarch64_url -O - | tar -xvz -C $darwin_aarch64_path
