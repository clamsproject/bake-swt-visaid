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
visaid_dir=${visaid_dir:-/visaid_builder-main}
visaid_py=${visaid_py:-$visaid_dir/.venv/bin/python3}
visaid_suffix=${visaid_suffix:-visaid.html}
no_mmif=${no_mmif:-0}

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
    cat $1 | jq -r '.visaid_params' > $tmpfname
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
    echo "  -x video_extensions : specify a comma-separated list of extensions"
    echo "[input_file_or_dir]   : one or more input files or directories to process"
    echo "  If a directory is provided, all files with the specified video extensions (by -x option) will be processed"
    exit 1
    
}

# getopts to get an argument for config name with `c` or ``config` flag
# all other arguments are treated as positional ones for target input files or directories
# if no config is provided, the default config (`default`) is used
confname=$(locate_config_file default)
OPTSTRING=":c:nx:h"
while getopts $OPTSTRING opt; do
    case $opt in
        c)
            confname=$(locate_config_file $OPTARG)
            ;;
        n)
            no_mmif=1
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
    local swt_conf=() ; while read -r line ; do swt_conf+=("$line") ;done <<< $(prep_swt_params $confname)
    visaid_conf_file=$(prep_visaid_params $confname)
    set -x
    clams source video:"$1" | $swt_py $swt_dir/cli.py "${swt_conf[@]}" -- > $output_dir/${vname}_$swt_suffix
    $visaid_py $visaid_dir/use_swt.py $output_dir/${vname}_$swt_suffix -vsc $visaid_conf_file > $output_dir/${vname}_$visaid_suffix
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
