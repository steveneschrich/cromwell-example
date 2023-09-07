# Cromwell Example

Step-by-step (maybe) of how to run a simple WDL pipeline

# Prerequisites
- internet access
- apptainer
- java (check version)

# Simplest Hello World
We are starting with the simplest workflow just to experiment.

## Setup
There is a ton of setup required to run cromwell. We are going to try and step through this setup as needed, rather than all up front.

## Download cromwell
Get the java jar files for the latest cromwell:

```sh
apptainer shell docker://gcc:latest
mkdir -p ~/.local/lib/cromwell
wget -O ~/.local/lib/cromwell/cromwell-85.jar https://github.com/broadinstitute/cromwell/releases/download/85/cromwell-85.jar 
wget -O ~/.local/lib/cromwell/womtool-85.jar https://github.com/broadinstitute/cromwell/releases/download/85/womtool-85.jar
```
## Create wrapper script
Calling cromwell (non-server mode) gets ever more complicated as we go, so start a basic wrapper script now. Create a `run_cromwell` script with the following:

```
#!/bin/bash

java -jar ${HOME}/.local/lib/cromwell/cromwell-85.jar run "$@"
```

Then execute
```sh
chmod 700 run_cromwell
```

## 01 - HelloWorld
A very simple hello world script (see `step-by-step/01-HelloWorld.wdl`):
```wdl
version 1.0

workflow HelloWorld {

	call hello_world {
		input: name="Cromwell"
	}

    output {
		File hello_world_result = hello_world.helloworld_file
	}

}

task hello_world {
	input {
		String name = "Oliver"
	}
	command  <<<
		echo "Hello world from ~{name}." > helloworld.txt
	>>>

	output {
		File helloworld_file = "helloworld.txt"
	}

}
```

We can run this using our wrapper script:
```sh
./run_cromwell step-by-step/01-HelloWorld.wdl
```

## 01 - Adding configuration
This is great except that we aren't using containers, just what is on the local system. In our case, we are using echo (a bash command), but we can imagine we need some specific application. A container can include all the necessary code for running the application, without local installation.

Recall that one of the prerequisites of this tutorial is to have apptainer. Assuming it's installed, we can tell cromwell to use apptainer to run containers rather than running on the current OS. This involves defining a backend provider (the scheme for running jobs) and telling cromwell to use this backend provider. 

### Configuration Part 1 (Cromwell Options)
We have a series of backend providers predefined at (https://raw.githubusercontent.com/steveneschrich/cromwell-config/main/backends.conf). So we can store these in ~/.local:

```sh
apptainer shell docker://gcc:latest
wget --no-check-certificate -O ~/.local/share/cromwell/backends.conf https://raw.githubusercontent.com/steveneschrich/cromwell-config/main/backends.conf
wget --no-check-certificate -O ~/.local/share/cromwell/cromwell.conf https://raw.githubusercontent.com/steveneschrich/cromwell-config/main/cromwell.conf
```

Next we start adding to how cromwell operates. We modify our wrapper script to use the config file.

```
java -Dconfig.file=$HOME/.local/share/cromwell/cromwell.conf -jar ~/.local/lib/cromwell/cromwell-85.jar run "$@"
```

But wait! We could run this again, but it wouldn't do anything differently yet. We have to tell cromwell to use a different backend provider. 

### Configuration Part 2 (Workflow Options)
In the previous step we setup system-level configuration (the backend providers that are available to use). However, we would also like to have workflow-level configuration. That is, we would like to tell cromwell that our specific workflow in this directory should use a specific backend provider for execution (among other options).

Create a file called `workflow-options.json` in the workflow launch directory. The contents (for now) can be simple and tell cromwell to default to the "apptainer" backend for running jobs:

```json
{
    "backend": "apptainer"
}
```

As before, let's modify our startup script to use this file. Notice I converted to multi-line in the hopes of keeping
it readable:
```
java \
    -Dconfig.file=$HOME/.local/share/cromwell/cromwell.conf -jar ~/.local/lib/cromwell/cromwell-85.jar \
    run \
        --options=./workflow-options.json \
        "$@"
```

Now you can run the same workflow (01-HelloWorld.wdl). 

### Containers
If you look closely at the output from the above run, you will see something like this:
```
MaterializeWorkflowDescriptorActor [81fb49f1]: Call-to-Backend assignments: HelloWorld.hi -> apptainer
```
This shows that the apptainer backend is being used. In fact, you can also find something like the following:
```
BackgroundConfigAsyncJobExecutionActor [81fb49f1HelloWorld.hello_world:NA:1]: executing: apptainer exec -C --bind /share/lab_eschrich/wdl/cromwell-example/cromwell-executions/HelloWorld/81fb49f1-0b44-4d42-adaa-d819f67e8b5a/call-hello_world:/cromwell-executions/HelloWorld/81fb49f1-0b44-4d42-adaa-d819f67e8b5a/call-hello_world  docker://ubuntu@sha256:aabed3296a3d45cede1dc866a24476c4d7e093aa806263c27ddaadbdce3c1054 /bin/bash /cromwell-executions/HelloWorld/81fb49f1-0b44-4d42-adaa-d819f67e8b5a/call-hello_world/execution/script
```

This shows us that the script (echo) is being executed within the "ubuntu" container. By default when using the apptainer backend, an ubuntu container will execute the command block of WDL tasks. Do note, however, that the base ubuntu image has very fews commands available. For all but trivial commands, this image will not work.

#### Specifying Containers: Workflow Default
Now that we have a workflow config file (workflow-options.json), we can add a different default docker container to use:
```
"default_runtime_attributes": {
        "docker": "debian:latest"
}
```

This results in the following output:
```
BackgroundConfigAsyncJobExecutionActor [fa640dc1HelloWorld.hi:NA:1]: executing: apptainer exec -C --bind /share/lab_eschrich/wdl/cromwell-example/cromwell-executions/HelloWorld/fa640dc1-d576-49c5-89c6-b02cec0d7557/call-hi:/cromwell-executions/HelloWorld/fa640dc1-d576-49c5-89c6-b02cec0d7557/call-hi  docker://debian@sha256:88b0908ef4de0f7015fd61b7fcbfa407854349af42d1e2081595768d575995c1 /bin/bash /cromwell-executions/HelloWorld/fa640dc1-d576-49c5-89c6-b02cec0d7557/call-hi/execution/script
```


#### Specifying Containers: Task Container

To specify a particular container to use for the task, we can use the `docker` keyword in the task `runtime` block. Here, we use 'gcc' instead of ubuntu to see the difference (gcc has build tools in the container):

```wdl
	runtime {
		docker: "gcc:latest"
	}
```

Running our new wdl (`02-HelloWorld.wdl`), we can see 
```
BackgroundConfigAsyncJobExecutionActor [d6867c96HelloWorld.hi:NA:1]: executing: apptainer exec -C --bind /share/lab_eschrich/wdl/cromwell-example/cromwell-executions/HelloWorld/d6867c96-0ba9-4d53-a10b-4d75be40a9c1/call-hi:/cromwell-executions/HelloWorld/d6867c96-0ba9-4d53-a10b-4d75be40a9c1/call-hi  docker://gcc@sha256:391fd3f22eedd3f8c77260b7539783b12f1b61fcc0caa12787e20a037a8cefe1 /bin/bash /cromwell-executions/HelloWorld/d6867c96-0ba9-4d53-a10b-4d75be40a9c1/call-hi/execution/script
```
Indicating that a gcc OS image was used instead.

### Comments
In general, when we run workflows we try to use containers for everything. When forcing the apptainer backend provider, this will always be the case. It is good practice to always include a container under which your task can run.

A larger point that should now be evident is that there are a number of "ancillary" files associated with cromwell. We are close to the end of these, but to recap:

- ~/.local/lib/cromwell - Jar files for cromwell and womtool which are needed to run
- ~/.local/share/cromwell - Cromwell-wide configuration files (backend.conf and cromwell.conf)
- workflow-options.json - Specific defaults/settings for the current workflow (not system-wide)
- run_cromwell - Wrapper script for running a workflow without having to remember all of the parameters. Note with sufficient convention, this can actually be in an arbitrary directory (like ~/bin).

See below for more details on what all you might put in these different files. My advice would be to try and keep as many files as possible outside of the local workflow so they are reused each time. And make the workflow-options.json file a template (or ~/.local/share/cromwell file).

# Extracting Workflow Outputs
As you have no doubt noticed, the workflow consists of many nested directories. This is great because you can always trace back through execution and figure out where something went wrong. But what about getting the result of the workflow? In our test case, there is a small file "helloworld.txt" that is written. If you look in the cromwell output you can see something like:
```
{
  "outputs": {
    "HelloWorld.hello_world_result": "/share/lab_eschrich/wdl/cromwell-example/cromwell-executions/HelloWorld/b9cdb959-fadc-4082-91b4-c109032932cc/call-hello_world/execution/helloworld.txt"
  },
  "id": "b9cdb959-fadc-4082-91b4-c109032932cc"
}
```
Great, at least I could find the file. But wow, that's pretty deeply embedded. Fortunately, this is something that we can configure in workflow options (workflow-options.json)! 

```json
{
    "final_workflow_outputs_dir" : "output_dir"
}
```

If you rerun the workflow, you will now have output in the directory "output_dir":
```
output_dir/HelloWorld/f57ee649-429b-4cb3-86c1-207059d8ca23/call-hello_world/execution/helloworld.txt
```
This is kind of ugly, but does not cause any name collisions. If instead you would like a flat output, you can include the following:
```
    "use_relative_output_paths": true
```
When doing this, you now have:
```
output_dir/helloworld.txt
```

There are some things to consider with this approach:
- Hundreds of output files would obviously make a flat approach more difficult.
- Running the workflow multiple times means that output is overwritten. This might be good or bad, depending on the application.
- If your workflow consists of multiple steps, then not keeping things separated out by task/workflow means name collisions can occur. `theresult.txt` could be the output of multiple stages, thus leading to overall collisions. Cromwell will error out when this happens.



# Using Reference Volumes
Often when considering genomics workflows, we use reference files. For instance, when aligning against the human reference one has to have the human reference available. These are big files and ideally we don't sling these around too much. Since we are using containers, one can actually mount files/filesystem images into the container and use them without needing to copy/localize this data.

For this exercise, we are going to significantly expand our HelloWorld to use "reference" files. In our case, we are considering a "reference" file: `ref/oliver.txt`. As you might expect, it just has the name "Oliver" in it. Our goal is to call our hello_world task with the reference and spit out the result.

First, we need to change the workflow to include the `dockerVolumes` attribute. This is where we specify the mapping (ref/oliver.txt to /reference.txt in the container). 

```wdl
workflow HelloWorld {

	call hello_world as hi_oliver {
		input: 
			name="Charles I",
			dockerVolumes = "ref/oliver.txt:/reference.txt"
	}
	output {
		File hello_oliver = hi_oliver.helloworld
	}

}
```
The task then has a new (optional) parameter called `dockerVolumes`. This parameter is referenced in the `runtime` section with the parameter `docker_volumes`. We could have hard-coded the value in runtime, but this approach allows the task to be independent of the specific application. 

```wdl
task hello_world {
	input {
		String name = ""
		String? dockerVolumes
	}

	command  <<<
		echo -n "Hello world from " | cat  - /reference.txt  > helloworld.txt
	>>>

	output {
		File helloworld = "helloworld.txt"
	}
	runtime {
		docker: "ubuntu:latest"
		docker_volumes: dockerVolumes
	}
}

```
Note in the command block we refer to `/reference.txt`. In this way, whatever dockerVolumes we include, the `/reference.txt` may change but the task itself does not change. This should not be a way to circumvent localization, however. Rather when there are a set of reference files to attach to an existing process.

# Running on the Cluster
Another common need for cromwell is to run workloads on a cluster. Here, we are going to be using slurm. All other aspects (apptainer, etc) remain the same. Our goal is to run the latest workflow (`03-HelloWorld.wdl`) but on the cluster. This requires a different backend (`slurm-apptainer`) which we can set in the workflow-options:

```
"backend": "slurm-apptainer"
```

Note that our task we defined (hello_world) contains no runtime attributes associated with the cluster. Therefore, we add these in to the task runtime_attributes. Generally, there are three cluster-specific parameters: time_minutes, cpu and memory.

The biowdl project uses a clever approach of naming the variables as input variables to the task, with some defaults. That way, these can easily overridden when needed.

```wdl
input {
		String name = ""
		String? dockerVolumes
		Int timeMinutes = 600
        Int cpu = 1
        String memory = "1G"
	}
```
Then the runtime attributes remain fixed:
```wdl
	runtime {
		docker: "ubuntu:latest"
		docker_volumes: dockerVolumes
		time_minutes: timeMinutes
		cpu: cpu
		memory: memory
	}
```

Based on this modification, we can run the entire process using the cluster:

```sh
sbatch run_cromwell step-by-step/04-HelloWorld.wdl
```
# TODO
Other topics to cover include:
- parameter_meta and the biowdl generation of documentation
- server mode
- input files!!




# Configuration options

## Wrapper Script
When invoking java, it's good to allocate a reasonable amount of RAM to avoid cromwell controller problems:
```
java -Xmx4G
```

Logging is copious with cromwell. While it can be easier to read log output on the screen when they are colored according to specific aspects, it makes it harder for programmatic access. So we usually use the `standard` option:
```
java -DLOG_MODE=standard 
```


## Workflow configuration
```
    "final_workflow_log_dir": "wf_logs",
    "final_call_logs_dir": "call_logs"
```