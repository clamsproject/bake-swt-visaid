#! /bin/bash 


# set to /data if not exported previously
data_dir=${data_dir:-/data}
output_dir=${output_dir:-/output}
swt_dir=${swt_dir:-/app}
swt_py=python3
swt_suffix=${swt_suffix:-swt.mmif}
visaid_dir=${visaid_dir:-/visaid_builder-main}
visaid_py=${visaid_py:-$visaid_dir/.venv/bin/python3}
visaid_suffix=${visaid_suffix:-visaid.html}

vid_exts="mp4 mkv avi"

# TODO: Add support for custom config files. For now, $swt_conf is an empty string hence the default config is used.
# test -e /config/swt.json && swt_conf=$(cat /config/swt.json) || swt_conf='--reasonable default --configs'
# test -e /config/visaid.json && visaid_conf=$(cat /config/visaid.json) || visaid_conf='--configued --for --html_ouput_to_stdout'

function process_video {
    vname=$(basename $1)
    clams source video:"$1" | $swt_py $swt_dir/cli.py $swt_conf -- > $output_dir/$vname.$swt_suffix
    $visaid_py $visaid_dir/use_swt.py $output_dir/$vname.$swt_suffix -vs > $data_dir/$vname.$visaid_suffix


for arg in $@; do 
    if [ ! -e $data_dir/$arg ]; then 
        echo "File $arg does not exist in $data_dir"
        exit 1
    fi
    if [ -f $data_dir/$arg ]; then
        process_video $data_dir/$arg
    elif [ -d $data_dir/$arg ]; then
        for ext in $vid_exts; do
            for vid in $(find $data_dir/$arg -type f -name "*.$ext"); do
                process_video $vid
            done
        done
    fi
done

