# Reasons for concurrency and parallelism


To complete this exercise you will have to use git. Create one or several commits that adds answers to the following questions and push it to your groups repository to complete the task.

When answering the questions, remember to use all the resources at your disposal. Asking the internet isn't a form of "cheating", it's a way of learning.

 ### What is concurrency? What is parallelism? What's the difference?
 > Concurrency is the ability to divide up a given program / algorithm and execute it out of order with the same final result. Parallelism is solving a problem by executing several calculations simultaneously. Though these seem very similar and often used together, there are differences and you can have one without the other. Concurrency just means that the program can be executed in a different order, while parallelism is just about executing several things at the same time.
 
 ### Why have machines become increasingly multicore in the past decade?
 > It has become increasingly difficult to increase computing speed of single core CPUs, as however fast they execute each instruction, they will still only execute one at a time. By having two cores, the processing speed could theoretically be doubled, and further increased with more cores. 
 
 ### What kinds of problems motivates the need for concurrent execution?
 (Or phrased differently: What problems do concurrency help in solving?)
 > Multithreading, executing programs on seperate cores, motivates the need for concurrent execution, as it makes it easy to execute a program on several cores. Concurrency states that the program could be rearranged and executed out of order, and as such could be executed on separate cores with little issue. 
 
 ### Does creating concurrent programs make the programmer's life easier? Harder? Maybe both?
 (Come back to this after you have worked on part 4 of this exercise)
 > *Your answer here*
 
 ### What are the differences between processes, threads, green threads, and coroutines?
 > The process is the overall structure of the program, and can include e.i. threads. The difference between threads and green threads is that green threads are schedueled by a virtual machine and not the operating system, while the difference between threads and coroutines is that coroutines are sequential, while threads can be executed in parallel. Concurrency vs Parallelism. 
 
 ### Which one of these do `pthread_create()` (C/POSIX), `threading.Thread()` (Python), `go` (Go) create?
 > `pthread_create()` starts a new thread, `threading.Thread()` creates a coroutine, unless the multiprocessing module is utilized, and `go` creates a go(co)routine. 
 
 ### How does pythons Global Interpreter Lock (GIL) influence the way a python Thread behaves?
 > GIL gives the control of the interpreter to just one of the threads, which can be a problem when using multi-threaded code.
 
 ### With this in mind: What is the workaround for the GIL (Hint: it's another module)?
 > Use the multiprocessing module. 
 
 ### What does `func GOMAXPROCS(n int) int` change? 
 > `func GOMAXPROCS(n int) int` sets the maximum number of CPUs that can be executing simultaneously. 
