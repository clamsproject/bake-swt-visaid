# Overview

This is a software package to analyze digital videos, to detect _scenes with text_ and create visual indexes ("visaids") showing those scenes.

The software is packaged as a Docker image that combines two pieces of software:
1. The [`swt-detection`](https://apps.clams.ai/#swt-detection) CLAMS app
2. The [`visaid-builder`](https://github.com/WGBH-MLA/visaid-builder) Python package

A visaid is a simple, portable HTML document displaying thumbnail images of key scenes from a video. Its purpose is to provide a visual index for overview and navigation. The following image is from [an example visaid](/examples/cpb-aacip-b45eb62bd60_visaid.html) for [an item in the American Archive of Public Broadcasting](https://americanarchive.org/catalog/cpb-aacip-b45eb62bd60).

![Screenshot of an example visaid](/examples/visaid_example_screenshot.png)
*Screenshot from an example visaid*

# Prerequisites

This software is intended to be run in a Docker container. So you need a container runtime (e.g., [Docker](https://www.docker.com/) or [Podman](https://podman.io/)). For this guide, we will assume the `docker` command is used.

We will also assume use of a `bash` shell, as available in Linux distributions, MacOS, and Windows (via WSL) systems.

# Before you start

The container runtime is the only software you install. You do not need Python, and you do not need to download or clone this repository. The image that you pull in the [Quick start](#quick-start) contains the tools and all their dependencies.

## Installing Docker Desktop on a Mac

1. Find the chip of your Mac in *Apple menu > About This Mac*. It is either Apple Silicon (M1, M2, ...) or Intel.
1. Download [Docker Desktop](https://www.docker.com/products/docker-desktop/) for that chip, and install it.
1. Start the Docker Desktop app. It must be running each time you use the `docker` command.
1. Open the Terminal app. All commands in this guide are typed there.
1. If your videos are not under your home directory (for example, on an external or network drive), make sure that their location is in the list in *Settings > Resources > File sharing* in Docker Desktop. If macOS asks to give Docker access to a folder, allow it.

## Checking the installation

Run this command in the terminal:

```
docker run --rm ghcr.io/clamsproject/bake-swt-visaid:latest -h
```

The first time, Docker downloads the image. The download is large and can take several minutes. When the installation is correct, the command prints a usage message that starts with `Usage: run.sh`.

- `command not found: docker`: Docker Desktop is not installed, or the terminal was opened before the installation. Open a new terminal window.
- `Cannot connect to the Docker daemon`: Docker Desktop is not running. Start the app and try again.

# Quick start

You need to acquire the Docker image. To pull the most recent version from our package repository available at GitHub Container Registry (ghcr), run 
```
docker pull ghcr.io/clamsproject/bake-swt-visaid:latest
```

Then, you need to identify two directories: **a directory containing input video files** and a **directory for the visaid output**. For example, suppose the following directories:

Videos directory: `/Users/casey/my_vids`

Outputs directory: `/Users/casey/visaids`

And suppose that the video you want to analyze is called `video1.mp4`. For your first run, use a short video (a few minutes), so that you see a result quickly.

Then, to create a visaid, run this command (substituting in the names of your directories and your video file):

```
docker run --rm -v /Users/casey/my_vids:/data -v /Users/casey/visaids:/output ghcr.io/clamsproject/bake-swt-visaid:latest video1.mp4
```

The terminal output should look similar to this:

```
Using config file: /presets/default.json
+ clams source video:/data/video1.mp4
+ python3 /app/cli.py --pretty true --tpUsePosModel true --tpModelName convnextv2_tiny --tpModelBatchSize 20 --tpStartAt 0 --tpStopAt 9000000 --tpSampleRate 250 --tfMinTPScore 0.05 --tfMinTFScore 0.12 --tfMinTFDuration 2650 --tfAllowOverlap false --tfLabelMapPreset nopreset --tfLabelMap B:bars S:slate IN:chyron Y:chyron 'M:main title' 'F:filmed text' CR:credits 'GLOTW:other text' 'E:other text' 'KU:other text' --
+ /visaid_builder/.venv/bin/visswt /output/video1_swt.mmif -v -c /tmp/visaid_params.1740685660.json -o /output/video1_visaid.html
+ set +x
```

When the command completes, the output directory contains two files: `video1_visaid.html` (the visaid) and `video1_swt.mmif` (the intermediate output of the `swt-detection` app).

Do not expect immediate results. Running this command on a 30-minute video may take 10-15 minutes (on a reasonably capable laptop without a GPU).

If your machine has a GPU with CUDA, you expect a speed up of 2x or more.  Add `--gpus all` to the Docker options to yield:

```
docker run --rm --gpus all -v /Users/casey/my_vids:/data -v /Users/casey/visaids:/output ghcr.io/clamsproject/bake-swt-visaid:latest video1.mp4
```

If you want to use one of the preset profiles, e.g., "fast-messy", you can add `-c fast-messy` to the container options (and now omitting GPU options), to yield:

```
docker run --rm -v /Users/casey/my_vids:/data -v /Users/casey/visaids:/output ghcr.io/clamsproject/bake-swt-visaid:latest -c fast-messy video1.mp4
```

# Memory and GPU

The image classifier in the `swt-detection` app processes video frames in batches, and larger batches need more memory. The presets set the batch size (`tpModelBatchSize`) to 20, a value that works on a laptop without a GPU.

- If the container stops with no error message (exit code 137), it ran out of memory. Give the container more memory, or use a custom configuration with a smaller `tpModelBatchSize` (see [Configuration](#configuration)).
- Docker Desktop (macOS and Windows) limits the memory that containers can use. You can change the limit in *Settings > Resources*.
- The `--gpus all` option needs an NVIDIA GPU and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html). It is not available on macOS; omit the option there.
- With a GPU, a larger `tpModelBatchSize` can increase the speed.

The image is published for both `amd64` (Intel/AMD) and `arm64` (Apple Silicon) machines, and `docker pull` selects the correct one automatically.

# Processing many videos

You can give more than one input, and an input can be a directory. All inputs are paths relative to the directory mounted to `/data`. For example, to process all videos in `/Users/casey/my_vids/batch1`:

```
docker run --rm -v /Users/casey/my_vids:/data -v /Users/casey/visaids:/output ghcr.io/clamsproject/bake-swt-visaid:latest batch1
```

- Directories are searched recursively for files with the video extensions set by the `-x` option (see [below](#configuring-the-baked-pipeline)).
- To process all videos in the mounted directory itself, use `.` as the input.
- Output files are named after the input file (`<name>_visaid.html` and `<name>_swt.mmif`) and are all written directly to the output directory. Two input files with the same name in different directories write to the same output files.
- Use the `-n` option if you do not need the MMIF files.

# General usage

In general, to run a Docker image in a container, the command format is: 

```
docker run [options for docker-run] <image-name> [options for the main command of the container]
```

To run the `bake-swt-visaid` Docker image, one needs two or three mount options (`-v xxx:yyy`), as in:

```
docker run --rm -v /path/to/data:/data -v /path/to/output:/output -v /path/to/config:/config bake-swt-visaid:latest [options] <input_files_or_directories>
```

- The `-v xxx:yyy` parts are for "mounting" partial file system to the container to share files between the host computer (`xxx` directory) and the container ("shown" as `yyy` inside the virtual machine). Two mounts are required:
    - `/data`: Directory containing input video files
    - `/output`: Directory to store output files
    - Then (optionally) mount the third directory containing the custom configuration file(s) to `/config`. See below for more information on configuration.
- The `[options]` part after the image name is configuring the baked pipeline itself. 
- And last (but not definitely least), the `<input_files_or_directories>` part is the (space-separated) list of input files or directories to process. If a directory is provided, all files with the specified video extensions (by `-x` option, see below) will be processed


# Configuration

There are two parts one can configure when running the docker-run command: 

## Configuring the baked pipeline 

This is the `[options]` part of the above example command. Available options are: 

- `-h` : display a help message and exit (do not use with other options)
- `-c config_name` : specify the configuration file to use (default is `default`, see below for what this configuration file is for)
- `-n` : do not output intermediate MMIF files (default is to output)
- `-x video_extensions` : specify a comma-separated list of extensions (default is `mp4,mkv,avi`)

> [!NOTE]
> All options are optional. If not specified, the default values will be used.

> [!NOTE]
> To handle video files, `ffmpeg` is installed inside the container (which is likely different from the `ffmpeg` on the host computer if already installed). To see information about the `ffmpeg` installation, for example to list up the available codecs, you can run the following command:
> ```
> docker run --rm --entrypoint "" ghcr.io/clamsproject/bake-swt-visaid:latest ffmpeg -codecs
> ```
> What's important here is the `--entrypoint ""` option, which disables the default command to run and run `ffmpeg ...` instead.


## Configuring individual elements in the pipeline

This can be done by passing a configuration file name using `-c` option. We provide some configuration presets in the [`presets`](presets) directory. 

### Using presets

Simply pass a preset name (without the `.json` extension) to the `-c` option. For example, to use the `fast-messy` preset:

```
docker run [options for docker-run] bake-swt-visaid:latest -c fast-messy input_video.mp4
``` 

The available presets can be glossed as follows:

- `default`: Reasonable compromise between speed and accuracy. Will be use when `-c` option is absent.
- `fast-messy`: Fast, imprecise, but still usable. (~2.5x speed of `default`)
- `single-bin`: Detects scenes with text, but does not distinguish between different types of scenes. (~1.3x speed of `default`)
- `just-sample`: Does not use scene identification; just creates a visaid via periodic sampling. (~5x speed of default)

> [!NOTE]
> The relative speeds are estimates and, in practice, depend on characteristics of the input video. The estimate assume use of GPU (CUDA). The multipliers will be exaggerated, increased by a factor of 2 or more, if processing is done only with CPU.*


### Using custom configuration

If you want to use a custom configuration, you need to 

1. create a JSON file with the configuration parameters
2. put the file in a directory that will be mounted to `/config` in the container
3. pass the file name (without the `.json` extension) to the `-c` option. For example, 

``` 
docker run [options for docker-run] -v /some/host/directory:/config bake-swt-visaid:latest -c custom_config input_video.mp4
```
with this `-c custom_config` option, it will look for `custom_config.json` file under `/config` inside the container, which is mapped from `/some/host/directory/custom_config.json` file in the host computer. It's important to make sure your configuration file is properly placed under the directory that's mounted to `/config`.

> [!WARNING]
> If your custom file in `/config` directory has the same name as one of the presets, the custom file will take precedence over the preset file.


# Advanced setup and configuration

## Building the docker image

If you want to build the image locally (maybe because you have specific modifications you need)  run the following command:

```
docker build -t bake-swt-visaid -f Containerfile .
```

> [!NOTE]
> In this repo, the image spec file name is (unconventionally) `Containerfile`, so you need to specify it with `-f` option.
 
This will build a local Docker image named `bake-swt-visaid` (or `bake-swt-visaid:latest` in full name with the "tag", they are synonymous). 

Within the container, the `run.sh` script is the main entry point for running the processing pipeline.

See [the container specification](Containerfile#L2-L3) for the exact versions of the tools used.


## Configuration file format
The JSON must have two keys; `swt_params` and `visaid_params`. These keys should contain the parameters for the `swt-detection` and `visaid-builder` tools, respectively.

```json
{
    "swt_params": {
        "param1": "value1",
        "param2": "value2"
    },
    "visaid_params": {
        "param1": "value1",
        "param2": "value2"
    }
}
```

For the `swt-detection` CLAMS app, see **Configurable Parameters** section in the documentation for the corresponding version, available at the [CLAMS AppDirectory](https://apps.clams.ai/#swt-detection). Read carefully the documentation to understand the parameters and their value formats.

> [!TIP]
> - CLAMS apps expect the parameters are passed as "string" values, so it's almost always safe to wrap the values in double quotes in JSON. 
> - For `multivalued=true` parameters (e.g., `tfDynamicSceneLabels` in the `swt-detection` app), you can pass an array of (string) values.
> - For `type=map` parameters (e.g., `tfLabelMap` in the `swt-detection` app), you CANNOT pass a JSON map object, but an array of strings in the format of `"key:value"`.

The `tfLabelMap` parameter sets the scene types that appear in the visaid. Each entry maps a label of the image classifier to a scene type name of your choice.

- The classifier labels in the current version are `B`, `S`, `M`, `Y`, `F`, `E`, `P`, `IN`, `KU`, `CR` and `GLOTW`.
- Set `tfLabelMapPreset` to `nopreset`. Otherwise, a built-in mapping of the app replaces your `tfLabelMap`.
- Labels that are absent from the map are not detected as scenes.
- The keys of `subsampling` in `visaid_params` must be scene type names used in `tfLabelMap`.

For the `visaid-builder` tool, see the [Configuration Parameters](https://github.com/WGBH-MLA/visaid-builder#configuration-parameters) section of its documentation.

> [!NOTE]
> The image uses a fixed version of `visaid-builder` (see [the container specification](Containerfile#L2-L3)), which can be older than the version that the linked documentation describes.

## Example configuration

See [`presets/default.json`](presets/default.json) for an example configuration file.

# Known issues and limitations

Names of input files and directories must not contain spaces.

The `swt-detection` CLAMS app uses an image classifier trained on stills from television programs in the [American Archive of Public Broadcasting](https://americanarchive.org/), especially public TV shows shot in a 4:3 aspect ratio, from the 1970s to the early 2000s.  You can expect the best results when applying this tool to videos that are visually similar to videos in the training data.

Development of this project, including the classifier, is ongoing.  We expect future releases to employ increasingly capable and efficient computer vision models.

