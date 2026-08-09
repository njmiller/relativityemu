package main

import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {

	fn1 := os.args[1]
	fn2 := os.args[2]

	data1_tmp, err1 := os.read_entire_file(fn1, context.allocator)
	if err1 != nil {
		fmt.eprintln("Could not read", fn1, ":", err1)
		os.exit(1)
	}
	data1 := strings.split_lines(auto_cast data1_tmp)

	data2_tmp, err2 := os.read_entire_file(fn2, context.allocator)
	if err2 != nil {
		fmt.eprintln("Could not read", fn2, ":", err2)
		os.exit(1)
	}
	data2 := strings.split_lines(auto_cast data2_tmp)

	nlines := len(data1) - 1 // because of a newline at the end of the log file

	fmt.println("Comparing", nlines, "lines")
	leq: int
	nchars := 74
	for i in 0 ..< nlines {
		if len(data1[i]) < nchars {
			fmt.println("Bad line length at line", i)
			return
		}
		line1 := data1[i][:nchars]
		line2 := data2[i][:nchars]

		leq = strings.compare(line1, line2)

		if leq != 0 {
			fmt.println("Ending at line number", i)
			fmt.println(line1)
			fmt.println(line2)

			fmt.println("Previous Line")
			fmt.println(data1[i - 1][:75])
			return
		}

	}

	fmt.println("All", nlines, "lines match")
}
