set -x
docker pull ghcr.io/clamsproject/bake-swt-visaid:latest 
docker run -it -v $(pwd)/data:/data -v $(pwd)/config:/config -v $(pwd)/output:/output --rm ghcr.io/clamsproject/bake-swt-visaid:latest cpb-aacip-29-01pg4g2x.h264.mp4
set +x
