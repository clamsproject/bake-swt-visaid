# Overview

This project provides a software package for processing video files using 
1. [`swt-detection`](https://apps.clams.ai/#swt-detection) CLAMS app
2. visual aids with `visaid_builder`. 

to detect _scenes-with-text_ and generate visualization of the detected scenes.

The `run.sh` script is the main entry point for running the processing pipeline.

See [the container specification](Containerfile#L2-L3) for the exact versions of the tools used.

# Prerequisites

- container runtime (e.g., [Docker](https://www.docker.com/) or [Podman](https://podman.io/)). For this guide, we will assume `docker` command is being used.
- `bash` shell (For Windows users, [WSL](https://learn.microsoft.com/en-us/windows/wsl/) is recommended to obtain a `bash` shell.)

> [!NOTE]
> TODO: add "# quick start" as a part of https://github.com/clamsproject/bake-swt-visaid/issues/5

# Setup

## Downloading prebuilt image
Simply pull from our package repository available at GtiHub Container Registry (ghcr):

```
docker pull ghcr.io/clamsproject/bake-swt-visaid:latest
```

and you're ready to go. See the [Usage](#usage) section for how to use the package. 

## Building the docker image

If you want to build the image locally (maybe because you have specific modifications you need)  run the following command:

```
docker build -t bake-swt-visaid -f Containerfile .
```

> [!NOTE]
> The image spec file name is (unconventionally) `Containerfile`, so you need to specify it with `-f` option.
 
This will build a local Docker image named `bake-swt-visaid` (or `bake-swt-visaid:latest` in full name with the "tag", they are synonymous). We will use this name in the following steps.

# Usage

## Running the Container

In general, to run a docker container, the command format is: 
```
docker run [options for docker-run] <image-name> [options for the main command of the container]
```

To run this bake container, specifically, one needs to use (at least) two or three mount options (`-v xxx:yyy`), as in:
```
docker run --rm -v /path/to/data:/data -v /path/to/output:/output -v /path/to/config:/config bake-swt-visaid:latest [options] <input_files_or_directories>
```

- `-v xxx:yyy` parts are for "mounting" parts of file system to the container to share files between the host computer (`xxx` directory) and the container ("shown" as `yyy` inside the virtual machine). Two mounts are required:
    - `/data`: Directory containing input video files
    - `/output`: Directory to store output files
    - Then (optionally) mount the third directory containing the custom configuration file(s) to `/config`. See below for more information on configuration.
- `[options]` part after the image name is configuring the baked pipeline itself. 
- And last (but not definitely least), the `<input_files_or_directories>` part is the (space-separated) list of input files or directories to process. If a directory is provided, all files with the specified video extensions (by `-x` option, see below) will be processed

# Configuration

There are two parts one can configure when running the docker-run command: 

## Configuing the baked pipeline 
This is the `[options]` part of the above example command. Available options are: 

- `-h` : display this help message
- `-c config_name` : specify the configuration file to use
- `-n` : do not output intermediate MMIF files
- `-x video_extensions` : specify a comma-separated list of extensions

> [!NOTE]
> All options are optional. If not specified, the default values will be used.

> [!NOTE]
> To handle video files, `ffmpeg` installed inside the container (which is likely different from the `ffmpeg` on the host computer if already installed) is used. To see information about the `ffmpeg` installation, for example to list up the available codecs, you can run the following command:
> ```
> docker run run -it --entrypoint "" bake_image_name ffmpeg -codecs
> ```
> What's important here is the `--entrypoint ""` option, which disables the default command to run and run `ffmpeg ...` instead.


## Configuring individual elements in the pipeline

This can be done by passing a configuration file name using `-c` option. We provide some configuration presets in the [`presets`](presets) directory. 

### Using presets
Simply pass a preset name (without the `.json` extension) to the `-c` option. For example:
```
docker run [options for docker-run] bake-swt-visaid:latest -c fast-messy input_video.mp4
```
to use `fast-messy` preset. 

> [!NOTE]
> If you don't use `-c` option at all, the `default` preset will be used.

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

#### Configuration File Format
The JSON must have two keys; `swt_params` and `visaid_params`. These keys should contain the parameters for the `swt-detection` and `visaid_builder` tools, respectively.

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
> - For `type=map` parameters (e.g., `tfLabelMap` in the `swt-detection` app), you CANNOT pass a JSON map object, but an array of strings in the format of `key:value`.

For the `visaid_builder` tool, the customizable parameters are documented [inside the tool's source code](https://github.com/WGBH-MLA/visaid_builder/blob/60cfadf67614251c215198a119a7dafc739a16de/proc_swt.py#L28-L38).
> [!NOTE]
> The URL to the source code can change when another version (commit) is used for the prebaked image.

#### Example Configuration

See [`presets/default.json`](presets/default.json) for an example configuration file.
