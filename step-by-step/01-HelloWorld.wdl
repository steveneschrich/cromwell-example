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

