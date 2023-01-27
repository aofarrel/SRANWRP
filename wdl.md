# WDL Information
WDL stands for Workflow Description Language. [You can read more about it here](https://openwdl.org/), but essentially is a language made for running batch tasks, usually by leveraging Docker. You don't enter the Docker container and then run the WDL script. Instead, you run the WDL script, which then does bash stuff in the Docker container.

The easiest way to run these workflows locally is using [miniwdl](https://github.com/chanzuckerberg/miniwdl), eg, `miniwdl run workflows/get_samples_from_runs.wdl -i workflows/get_samples_from_runs.json` Alternatively, you can launch these workflows on [Terra](https://terra.bio/). For more information on running WDLs, [see this beginner's guide](https://github.com/ucsc-cgp/training-resources/blob/main/WDL/running_a_wdl.md).

## Common arguments used by WDLs in this repo
**disk_size** (default: 50 gigabytes)  
What disk size to use. Treated as a maximum by GCP (including Terra) and a minimum by some other backends. Ignored on local backends.

**fail_on_invalid** (default: false)  
If you set fail_on_invalid == true and fasterq-dump returns an odd number of files that is not 3, then the WDL task will return 1. When fasterq-dump returns 3 files, it is usually one file we can throw out plus two valid read files, so even if fail_on_invalid == true the code will not fail on the 3 file case.

**preempt** (default: use preemptibles once)  
iif running on GCP (including Terra), attempt the task on a [preemptible instance](https://cloud.google.com/compute/docs/instances/preemptible) this number of times. Afterwards, attempt the task once on a non-preemptible instance. If not running on GCP this input is ignored.
