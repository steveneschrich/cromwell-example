version 1.0

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

