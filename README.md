# README

## Overview

This project provides a Docker container setup for processing video files using 
1. [`swt-detection`](https://apps.clams.ai/#swt-detection) CLAMS app
2. visual aids with `visaid_builder`. The `run.sh` script is the main entry point for running the processing pipeline.

See [the container specification](Containerfile#L2-L3) for the exact versions of the tools used.

## Prerequisites

- container runtime (e.g., Docker or Podman). For this guide, we will assume `docker` command is being used.
- `bash` shell (For Windows users, [WSL](https://learn.microsoft.com/en-us/windows/wsl/) is recommended to obtain a bash shell.)

## Usage

### Building the Docker Image

To build the Docker image, run the following command:

```
docker build -t video-processor .
```
This will build a local Docker image named `video-processor`. We will use this name in the following steps.

### Running the Container

To run the container, use the following command:

```
docker run --rm -v /path/to/data:/data -v /path/to/output:/output -v /path/to/config:/config video-processor [options] [input_files_or_directories]
```

### Mounts

At least two mounts are required:

- `/data`: Directory containing input video files
- `/output`: Directory to store output files

Then mount the directory containing the custom configuration file(s) to `/config`. See below for more information on configuration.


### Environment Variables

The following environment variables can be overridden:

- `data_dir`: Directory containing input video files (default: `/data`)
- `output_dir`: Directory to store output files (default: `/output`)
- `config_user_dir`: Directory containing user configuration files (default: `/config`)
- `vid_exts`: Video file extensions to process (default: `mp4 mkv avi`), separated by spaces. Only applies when input is a directory.

If necessary, use the [`-e` option](https://docs.docker.com/reference/cli/docker/container/run/#env) to set these environment variables. For example:

```
docker run --rm -v /path/to/data:/data -v /path/to/output:/output -e vid_exts="mp4" video-processor a_sub_dir
```

This command will process all `.mp4` files in the `/path/to/data/a_sub_dir` directory, and store the output in `/path/to/output`.

### Configuration

Configuration can be passed as a single JSON file using the `-c` option. For example:
``` 
docker run <docker options> video-processor -c custom_config input_video.mp4
```
with this `-c custom_config` option, it will look for `custom_config.json` file under `/config` and `/presets` directories (in that order) inside the container. Make sure your configuration file is placed under the directory that's mounted to `/config`.

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

