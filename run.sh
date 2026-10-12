#! /bin/bash 

# let user know that they can override the following variables
data_dir=${data_dir:-/data}
output_dir=${output_dir:-/output}
config_user_dir=${config_user_dir:-/config}
vid_exts=${vid_exts:-"mp4,mkv,avi"}

# these are more like to be hardcoded
config_preset_dir=${config_preset_dir:-/presets}
swt_dir=${swt_dir:-/app}
swt_py=python3
swt_suffix=${swt_suffix:-swt.mmif}
visaid_dir=${visaid_dir:-/visaid_builder}
visswt=${visswt:-$visaid_dir/.venv/bin/visswt}
visaid_suffix=${visaid_suffix:-visaid.html}
no_mmif=${no_mmif:-0}
skip=${skip:-0}
failed=()

function locate_config_file {
    # if $1 is an absolute path (starts with /), and exists, return it
    if [[ "$1" == /* && -e "$1" ]]; then
        echo $1
        return
    # if $1 is a string with no slashes, search for it in 1) /config 2) /presets 
    elif [[ "$1" != */* ]]; then
        # make sure $1 has .json extension, if not already
        if [[ "$1" != *.json ]]; then
            config_json="$1.json"
        else
            config_json="$1"
        fi
        
        if [ -e "$config_user_dir/$config_json" ]; then
            echo $config_user_dir/$config_json
            return
        elif [ -e "$config_preset_dir/$config_json" ]; then
            echo $config_preset_dir/$config_json
            return
        else
            echo "Error: $1 is not a valid configuration key"
            exit 1
        fi
    else
        # no relative paths allowed
        echo "Error: $1 is not a valid configuration key"
        exit 1
    fi
}

function prep_visaid_params {
    # jq config file ($1) and grab the visaid_params object and dump to a tmp file using a random name to avoid being reused, return the path
    tmpfname=/tmp/visaid_params.$(date +%s).json
    cat $1 | jq -r '.visaid_params // {}' > $tmpfname
    echo $tmpfname
}

function prep_swt_params {
    # jq config file ($1) and grab the swt_params object and dump to a concatenated string of key value pairs in CLI format, one per line so that bash can read them into an array
    cat $1 | \
        jq -r '. | .swt_params | to_entries | reduce .[] as $ent ([] ;. + ["--\($ent.key)", ($ent.value | if type == "array" then (. | map(tostring)[] ) else tostring end)]) | .[]'
}

function usage {
    echo "Usage: run.sh [-c config_name] [input_file_or_dir ...]"
    echo "Options:"
    echo "  -h                  : display this help message"
    echo "  -c config_name      : specify the configuration file to use"
    echo "  -n                  : do not output intermediate MMIF files"
    echo "  -s, --skip          : skip a video when its visaid already exists"
    echo "  -x video_extensions : specify a comma-separated list of extensions"
    echo "[input_file_or_dir]   : one or more input files or directories to process"
    echo "  If a directory is provided, all files with the specified video extensions (by -x option) will be processed"
    exit 1
    
}

# getopts handles short options only, so translate the long ones first
args=()
for arg in "$@"; do
    case $arg in
        --skip) args+=(-s) ;;
        *) args+=("$arg") ;;
    esac
done
set -- "${args[@]}"

# getopts to get an argument for config name with `c` or ``config` flag
# all other arguments are treated as positional ones for target input files or directories
# if no config is provided, the default config (`default`) is used
confname=$(locate_config_file default)
OPTSTRING=":c:nsx:h"
while getopts $OPTSTRING opt; do
    case $opt in
        c)
            confname=$(locate_config_file $OPTARG)
            ;;
        n)
            no_mmif=1
            ;;
        s)
            skip=1
            ;;
        x)
            vid_exts=$OPTARG
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

echo "Using config file: $confname"

function process_video {
    vname=$(basename $1)
    vname=${vname%.*}
    if [ $skip -eq 1 ] && [ -e $output_dir/${vname}_$visaid_suffix ]; then
        echo "Skipping $1: $output_dir/${vname}_$visaid_suffix already exists"
        return
    fi
    local swt_conf=() ; while read -r line ; do swt_conf+=("$line") ;done <<< $(prep_swt_params $confname)
    visaid_conf_file=$(prep_visaid_params $confname)
    # the MMIF file of a failed video is kept, because it records the error
    set -x
    if ! clams source video:"$1" | $swt_py $swt_dir/cli.py "${swt_conf[@]}" -- > $output_dir/${vname}_$swt_suffix; then
        set +x
        echo "Error: scene detection failed for $1, see $output_dir/${vname}_$swt_suffix"
        failed+=("$1")
        return
    fi
    if ! $visswt $output_dir/${vname}_$swt_suffix -v -c $visaid_conf_file -o $output_dir/${vname}_$visaid_suffix; then
        set +x
        echo "Error: visaid creation failed for $1"
        # an incomplete visaid must not make the next run skip this video
        rm -f $output_dir/${vname}_$visaid_suffix
        failed+=("$1")
        return
    fi
    set +x
    # delete swt output if no_mmif is set
    if [ $no_mmif -eq 1 ]; then
        set -x
        rm $output_dir/${vname}_$swt_suffix
        set +x
    fi
}

for arg in $@; do 
    if [ ! -e $data_dir/$arg ]; then 
        echo "File $arg does not exist in $data_dir"
        exit 1
    fi
    if [ -f $data_dir/$arg ]; then
        process_video $data_dir/$arg
    elif [ -d $data_dir/$arg ]; then
        for ext in ${vid_exts//,/ }; do
            for vid in $(find $data_dir/$arg -type f -name "*.$ext"); do
                process_video $vid
            done
        done
    fi
done

if [ ${#failed[@]} -gt 0 ]; then
    echo "Failed to process ${#failed[@]} video(s):"
    printf '  %s\n' "${failed[@]}"
    exit 1
fi
