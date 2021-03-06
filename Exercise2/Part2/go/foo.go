// Use `go run foo.go` to run your program

package main

import (
    . "fmt"
    "runtime"
)

// Control signals
const (
	GetNumber = iota
	Exit
)

func number_server(add_number <-chan int, exit <-chan bool, number chan<- int, getnumb <-chan bool) {
	var i = 0

	// This for-select pattern is one you will become familiar with if you're using go "correctly".
	for {
		select {
			// TODO: receive different messages and handle them correctly
			// You will at least need to update the number and handle control signals.
		case a := <- add_number:
			i += a
		case <-getnumb:
			number <- i
		case <-exit:
			return
		}
	}
}

func incrementing(add_number chan<-int, finished chan<- bool) {
	for j := 0; j<1000000 + 1; j++ {
		add_number <- 1
	}
	finished <- true
}

func decrementing(add_number chan<- int, finished chan<- bool) {
	for j := 0; j<1000000; j++ {
		add_number <- -1
	}
	finished <- true
}

func main() {
	runtime.GOMAXPROCS(1)

	// TODO: Construct the required channels
	// Think about wether the receptions of the number should be unbuffered, or buffered with a fixed queue size.
	add_number := make(chan int)
	finished := make(chan bool)
	number := make(chan int)
	exit := make(chan bool)
	getnumb := make(chan bool)

	// TODO: Spawn the required goroutines
	go incrementing(add_number, finished)
	go decrementing(add_number, finished)
	go number_server(add_number, exit, number, getnumb)

	<-finished
	<-finished
	getnumb <- true
	
	Println("The magic number is:", <-number)
	exit<-true
}
