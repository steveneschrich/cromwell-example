version 1.0

workflow HelloWorld {

	call hello_world as hi_oliver {
		input: 
			name="Charles I",
			dockerVolumes = "/share/lab_eschrich/wdl/cromwell-example/ref/oliver.txt:/reference.txt"
	}
	output {
		File hello_oliver = hi_oliver.helloworld
	}

}

task hello_world {
	input {
		String name = ""
		String? dockerVolumes
		Int timeMinutes = 600
        Int cpu = 1
        String memory = "1G"
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
		time_minutes: timeMinutes
		cpu: cpu
		memory: memory
	}
}

